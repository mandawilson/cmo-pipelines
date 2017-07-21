/*
 * Copyright (c) 2016 - 2017 Memorial Sloan-Kettering Cancer Center.
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

package org.cbioportal.cmo.pipelines.cvr.clinical;

import org.cbioportal.cmo.pipelines.cvr.model.*;
import org.cbioportal.cmo.pipelines.cvr.CvrSampleListUtil;

import java.util.*;
import org.apache.commons.lang.StringUtils;
import org.springframework.batch.item.ItemProcessor;
import org.springframework.beans.factory.annotation.Autowired;

/**
 *
 * @author heinsz
 */
public class CVRClinicalDataProcessor implements ItemProcessor<CVRClinicalRecord, CompositeClinicalRecord> {

    @Autowired
    public CvrSampleListUtil cvrSampleListUtil;
    
    @Override
    public CompositeClinicalRecord process(CVRClinicalRecord i) throws Exception {
        List<String> record = new ArrayList<>();
        List<String> seqDateRecord = new ArrayList<>();
        for (String field : CVRClinicalRecord.getFieldNames()) {
            record.add(i.getClass().getMethod("get" + field).invoke(i).toString().replaceAll("[\\t\\n\\r]+"," "));
        }
        for (String field : MskimpactSeqDate.getFieldNames()) {
            seqDateRecord.add(i.getClass().getMethod("get" + field).invoke(i).toString().replaceAll("[\\t\\n\\r]+"," "));
        }
        CompositeClinicalRecord compRecord = new CompositeClinicalRecord();
        if (cvrSampleListUtil.getNewDmpSamples().contains(i.getSAMPLE_ID())) {
            compRecord.setNewClinicalRecord(StringUtils.join(record, "\t").trim());
        } else {
            compRecord.setOldClinicalRecord(StringUtils.join(record, "\t").trim());
        }
        compRecord.setSeqDateRecord(StringUtils.join(seqDateRecord, "\t").trim());
        return compRecord;
    }
}
