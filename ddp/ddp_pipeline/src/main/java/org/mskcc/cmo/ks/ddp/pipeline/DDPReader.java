/*
 * Copyright (c) 2018-2023 Memorial Sloan-Kettering Cancer Center.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY, WITHOUT EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS
 * FOR A PARTICULAR PURPOSE. The software and documentation provided hereunder
 * is on an "as is" basis, and Memorial Sloan-Kettering Cancer Center has no
 * obligations to provide maintenance, support, updates, enhancements or
 * modifications. In no event shall Memorial Sloan-Kettering Cancer Center be
 * liable to any party for direct, indirect, special, incidental or
 * consequential damages, including lost profits, arising out of the use of this
 * software and its documentation, even if Memorial Sloan-Kettering Cancer
 * Center has been advised of the possibility of such damage.
 */

/*
 * This file is part of cBioPortal CMO-Pipelines.
 *
 * cBioPortal is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

package org.mskcc.cmo.ks.ddp.pipeline;

import org.mskcc.cmo.ks.ddp.source.DDPDataSource;
import org.mskcc.cmo.ks.ddp.source.util.AuthenticationUtil;
import org.mskcc.cmo.ks.ddp.source.composite.DDPCompositeRecord;
import org.mskcc.cmo.ks.ddp.source.model.CohortPatient;
import org.mskcc.cmo.ks.ddp.source.model.PatientIdentifiers;
import org.mskcc.cmo.ks.ddp.pipeline.util.DDPPatientListUtil;

import com.google.common.base.Strings;
import java.io.*;
import java.util.*;
import javax.annotation.Resource;
import org.apache.log4j.Logger;
import org.springframework.batch.item.*;
import org.springframework.beans.factory.annotation.*;

import java.util.concurrent.CompletableFuture;
import org.apache.commons.lang.StringUtils;
/**
 *
 * @author ochoaa
 */
public class DDPReader implements ItemStreamReader<DDPCompositeRecord> {

    @Value("#{jobParameters[cohortName]}")
    private String cohortName;

    @Value("#{jobParameters[subsetFilename]}")
    private String subsetFilename;

    @Value("#{jobParameters[excludedPatientsFilename]}")
    private String excludedPatientsFilename;

    @Value("#{jobParameters[testMode]}")
    private Boolean testMode;

    @Resource(name = "ddpCohortMap")
    private Map<String, Integer> ddpCohortMap;

    @Autowired
    private DDPDataSource ddpDataSource;

    @Autowired
    private DDPPatientListUtil ddpPatientListUtil;

    @Autowired
    private AuthenticationUtil authenticationUtil;

    private List<DDPCompositeRecord> ddpCompositeRecordList;
    private Set<String> excludedPatientIds = new HashSet<>();
    private final String MSKIMPACT_PED_COHORT_NAME = "mskimpact_ped";
    private final Integer TEST_MODE_PATIENT_THRESHOLD = 500;

    private final Logger LOG = Logger.getLogger(DDPReader.class);

    @Override
    public void open(ExecutionContext ec) throws ItemStreamException {
        if (testMode) {
            LOG.info("Running DDP pipeline in test mode - data will only be processed for " + TEST_MODE_PATIENT_THRESHOLD + " patients");
        }
        // load patient ids to exclude from final result set if excludePatientsFilename provided
        if (!Strings.isNullOrEmpty(excludedPatientsFilename)) {
            try {
                this.excludedPatientIds = loadPatientIdsFromFile(excludedPatientsFilename);
            } catch (FileNotFoundException e) {
                throw new ItemStreamException("Error loading excluded patient ids from: " + excludedPatientsFilename, e);
            }
        }
        // get composite records patient ids from subsetFilename, otherwise fetch records by cohort id
        if (!Strings.isNullOrEmpty(subsetFilename)) {
            try {
                this.ddpCompositeRecordList = getCompositeRecordsByPatientIds();
            } catch (Exception e) {
                throw new ItemStreamException("Error fetching DDP records by subset ids: " + subsetFilename, e);
            }
        }
        else {
            try {
                this.ddpCompositeRecordList = getCompositeRecordsByCohortId();
            }
            catch (Exception e) {
                throw new ItemStreamException("Error fetching DDP records by cohort name: " + cohortName, e);
            }
        }
        // add pediatric cohort patient ids to execution context for processor
        ec.put("pediatricCohortPatientIdsSet", getPediatricCohortPatientIdsSet());
        LOG.info("Fetched " + ddpCompositeRecordList.size() +  " DDP records");
    }

    /**
     * Fetches the pediatric cohort patient list from DDP.
     * The set of DDP IDs will be used to update the pediatric cohort status
     * of a composite patient record during the processing step.
     *
     * @return
     */
    private Set<Integer> getPediatricCohortPatientIdsSet() {
        Set<Integer> pediatricCohortPatientIdsSet = new HashSet<>();
        try {
            List<CohortPatient> mskimpactPedPatients = ddpDataSource.getPatientRecordsByCohortId(ddpCohortMap.get(MSKIMPACT_PED_COHORT_NAME));
            for (CohortPatient patient : mskimpactPedPatients) {
                pediatricCohortPatientIdsSet.add(patient.getPID());
            }
            LOG.info("Successfully fetched " + String.valueOf(mskimpactPedPatients.size()) + " DDP patient IDs belonging to " + MSKIMPACT_PED_COHORT_NAME + " cohort");
        } catch (Exception e) {
            LOG.error("Error fetching DDP pediatric cohort patient list - will not be able to update PED_IND status for clinical data");
        }
        return pediatricCohortPatientIdsSet;
    }

    /**
     * Returns a unique set of composite records for given cohort id..
     *
     * @return
     */
    private List<DDPCompositeRecord> getCompositeRecordsByCohortId() throws Exception {
        Integer cohortId = ddpCohortMap.get(cohortName);
        if (cohortId == null) {
            throw new ItemStreamException("Cohort not known by name: " + cohortName);
        }
        // get composite records from DDP by cohort id
        List<DDPCompositeRecord> records = getDDPCompositeRecordsByCohortId(cohortId);
        return records;
    }

    /**
     * Helper function to return a unique set of composite records for a list of patient ids.
     * Patient ids can either be P_IDs from the cohort endpoint or DMP ids.
     *
     * Removes records matching ids in 'excludedPatientIds' if necessary.
     *
     * @param cohortId
     * @return
     */
    private Map<String, DDPCompositeRecord> getDDPCompositeRecords(Set<String> patientIds) throws Exception {
        Map<String, DDPCompositeRecord> compositeRecords = new HashMap<String, DDPCompositeRecord>();
        Map<String, CompletableFuture<PatientIdentifiers>> futurePatientIdentifiers = new HashMap<String, CompletableFuture<PatientIdentifiers>>();

        int count = 0;
        for (String patientId : patientIds) {
            try {
                // getPatientIdentifiers() is an Async function meaning the loop does not depend on request being completed
                futurePatientIdentifiers.put(patientId, ddpDataSource.getPatientIdentifiers(patientId));
            } catch (Exception e) {
                LOG.error("Failed to resolve dmp id's for record'" + patientId + "' -- skipping (" + e.getMessage() + ")");
                ddpPatientListUtil.addPatientsMissingDMPId(patientId);
            }
            count++;
            if (testMode && count >= TEST_MODE_PATIENT_THRESHOLD) {
                break;
            }
        }

        // ensures composite records will not be created until all requests for Patient Identifiers are completed
        for (String patientIdentifier : futurePatientIdentifiers.keySet()) {
            getCompletableFuturePatientIdentifiers(patientIdentifier, futurePatientIdentifiers);
        }

        LOG.info("creating composite Records");
        for(String patientIdentifier : futurePatientIdentifiers.keySet()) {
            PatientIdentifiers pids = getCompletableFuturePatientIdentifiers(patientIdentifier, futurePatientIdentifiers);
            if (pids != null && !Strings.isNullOrEmpty(pids.getDmpPatientId())) {
                if (pids.getDmpPatientId().equals("P-0000000")) {
                    LOG.error("Patient ID " + patientIdentifier + " resolved to DMP ID: P-0000000");
                    continue;
                }
                compositeRecords.put(patientIdentifier, new DDPCompositeRecord(pids.getDmpPatientId(), pids.getDmpSampleIds()));
            } else {
                LOG.error("Failed to resolve dmp id's for record '" + patientIdentifier + "' -- skipping");
                ddpPatientListUtil.addPatientsMissingDMPId(patientIdentifier);
                continue;
            }
        }
        // filter composite records to return if excluded patient id list is not empty
        if (!excludedPatientIds.isEmpty()) {
            return filterCompositeRecords(compositeRecords);
        }
        return compositeRecords;
    }

    /**
     * Helper function to return a unique set of composite records for cohort ids.
     *
     * Removes records matching ids in 'excludedPatientIds' if necessary.
     *
     * @param cohortId
     * @return
     */
    private List<DDPCompositeRecord> getDDPCompositeRecordsByCohortId(Integer cohortId) throws Exception {
        List<CohortPatient> records = ddpDataSource.getPatientRecordsByCohortId(cohortId);
        LOG.info("Fetched " + records.size()+  " active patients for cohort: " + cohortName);

        Map<String, CohortPatient> cohortPatientRecords = new HashMap<String, CohortPatient>();
        for (CohortPatient record : records) {
            cohortPatientRecords.put(record.getPID().toString(), record);
        }

        Map<String, DDPCompositeRecord> compositeRecords = getDDPCompositeRecords(cohortPatientRecords.keySet());
        for (Map.Entry<String, DDPCompositeRecord> entry: compositeRecords.entrySet()) {
            entry.getValue().setCohortPatient(cohortPatientRecords.get(entry.getKey()));
        }
	return new ArrayList<>(compositeRecords.values());
    }

    /**
     * Returns null if exception thrown while calling future patient identifiers.
     *
     * This can happen if we get a 403 Forbidden for high profile patients, which we do not have access to.
     * There are also 401 unauthorized errors. These are thrown when we are not authorized yet to
     * fetch data for these patients.
     * @param pid
     * @param futurePatientIdentifiers
     * @return
     */
    private PatientIdentifiers getCompletableFuturePatientIdentifiers(String pid, Map<String, CompletableFuture<PatientIdentifiers>> futurePatientIdentifiers) {
        try {
            return futurePatientIdentifiers.get(pid).get();
        } catch (Exception e) {}
        return null;
    }

    /**
     * Returns a unique set of composite records for patient ids stored in subsetFilename.
     *
     * @return
     */
    private List<DDPCompositeRecord> getCompositeRecordsByPatientIds() throws Exception {
        Set<String> patientIds = new HashSet<>();
        try {
            patientIds = loadPatientIdsFromFile(subsetFilename);
        } catch (FileNotFoundException e) {
            throw new ItemStreamException("Error loading patient ids from: " + subsetFilename, e);
        }
        List<DDPCompositeRecord> records = getDDPCompositeRecordsByPatientIds(patientIds);
        return records;
    }

    /**
     * Helper function to return a unique set of composite records for given patient ids.
     *
     * Removes records matching patient ids in 'excludedPatientIds' if necessary.
     *
     * @param patientIds
     * @param records CohortPatient records, might be null
     * @return
     */
    private List<DDPCompositeRecord> getDDPCompositeRecordsByPatientIds(Set<String> patientIds) throws Exception {
        Map<String, DDPCompositeRecord> compositeRecords = getDDPCompositeRecords(patientIds);
	return new ArrayList<>(compositeRecords.values());
    }

    /**
     * Loads patient ids from given file.
     *
     * File contains line-delimited list of patient ids.
     *
     * @param filename
     * @return
     * @throws FileNotFoundException
     */
    private Set<String> loadPatientIdsFromFile(String filename) throws FileNotFoundException {
        Set<String> patientIds = new HashSet<>();
        Scanner reader = new Scanner(new File(filename));
        while (reader.hasNext()) {
            patientIds.add(reader.nextLine().trim());
        }
        reader.close();
        if (patientIds.isEmpty()) {
            throw new ItemStreamException("Error loading patient ids from: " + subsetFilename);
        }
        LOG.info("Loaded " + patientIds.size() + " patient ids from: " + subsetFilename);
        return patientIds;
    }

    /**
     * Removes records from the given composite record list if found in the excluded patient ids list.
     *
     * @return
     */
    private Map<String, DDPCompositeRecord> filterCompositeRecords(Map<String, DDPCompositeRecord> compositeRecords) {
        LOG.info("Removing composite records matching ids in 'excludedPatientIds'...");
        Map<String, DDPCompositeRecord> filteredCompositeRecords = new HashMap<>();
        for (Map.Entry<String, DDPCompositeRecord> entry: compositeRecords.entrySet()) {
            if (excludedPatientIds.contains(entry.getValue().getDmpPatientId())) {
                continue;
            }
            filteredCompositeRecords.put(entry.getKey(), entry.getValue());
        }
        LOG.info("Removed " + (compositeRecords.size() - filteredCompositeRecords.size()) + " from final composite record set");
        return filteredCompositeRecords;
    }

    @Override
    public void update(ExecutionContext ec) throws ItemStreamException {}

    @Override
    public void close() throws ItemStreamException {}

    @Override
    public DDPCompositeRecord read() throws Exception, UnexpectedInputException, ParseException, NonTransientResourceException {
        if (!ddpCompositeRecordList.isEmpty()) {
            return ddpCompositeRecordList.remove(0);
        }
        return null;
    }
}
