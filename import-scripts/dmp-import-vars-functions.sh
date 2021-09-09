#!/bin/bash

## GLOBALS

ONCOTREE_VERSION_TO_USE=oncotree_candidate_release
CVR_TEST_MODE_ARGS=""
PERFORM_CRDB_FETCH=0
PROCESS_UNLINKED_ARCHER_STUDY=0
CRDB_FETCHER_JAR_FILENAME="$PORTAL_HOME/lib/crdb_fetcher.jar"
CVR_FETCHER_JAR_FILENAME="$PORTAL_HOME/lib/cvr_fetcher.jar"
DARWIN_FETCHER_JAR_FILENAME="$PORTAL_HOME/lib/darwin_fetcher.jar"
DDP_FETCHER_JAR_FILENAME="$PORTAL_HOME/lib/ddp_fetcher.jar"
REDCAP_PIPELINE_JAR_FILENAME="$PORTAL_HOME/lib/redcap_pipeline.jar"
IMPORTER_JAR_FILENAME="$PORTAL_HOME/lib/msk-dmp-importer.jar"
JAVA_CRDB_FETCHER_ARGS="-jar $CRDB_FETCHER_JAR_FILENAME"
JAVA_CVR_FETCHER_ARGS="-jar $CVR_FETCHER_JAR_FILENAME"
JAVA_DARWIN_FETCHER_ARGS="-jar $DARWIN_FETCHER_JAR_FILENAME"
JAVA_DDP_FETCHER_ARGS="-jar $DDP_FETCHER_JAR_FILENAME"
JAVA_REDCAP_PIPELINE_ARGS="$JAVA_SSL_ARGS -jar $REDCAP_PIPELINE_JAR_FILENAME"
java_debug_args=""
ENABLE_DEBUGGING=0
if [ $ENABLE_DEBUGGING != "0" ] ; then
    java_debug_args="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=27182"
fi
JAVA_IMPORTER_ARGS="$JAVA_PROXY_ARGS $java_debug_args $JAVA_SSL_ARGS -Dspring.profiles.active=dbcp -Djava.io.tmpdir=$MSK_DMP_TMPDIR -ea -cp $IMPORTER_JAR_FILENAME org.mskcc.cbio.importer.Admin"
PIPELINES_EMAIL_LIST="cbioportal-pipelines@cbio.mskcc.org"
SLACK_PIPELINES_MONITOR_URL=`cat $SLACK_URL_FILE`

DEFAULT_DDP_DEMOGRAPHICS_ROW_COUNT=2

# Clinical attribute fields which should never be filtered because of empty content
FILTER_EMPTY_COLUMNS_KEEP_COLUMN_LIST="PATIENT_ID,SAMPLE_ID,ONCOTREE_CODE,PARTA_CONSENTED_12_245,PARTC_CONSENTED_12_245"

# -----------------------------------------------------------------------------------------------------------
## FUNCTIONS

# Function to extract property settings from a simple properties file
# usage : extractPropertiesFromFile sourcefile.properties propertyname1 propertyname2 propertyname3 ...
# caller must 'declare -Ax extracted_properties' before calling this function
function extractPropertiesFromFile() {
    if [ $# -lt 1 ] ; then
        return 1 # error -- insufficient arguments
    fi
    PROPERTIES_FILENAME=$1
    shift 1
    if [ ! -r $PROPERTIES_FILENAME ] ; then
        return 2 # error -- cannot read file
    fi
    # test and reset return array
    if ! declare -A | grep " extracted_properties=" > /dev/null 2>&1 ; then
        return 3 # error -- caller did not declare extracted_properties associative array
    fi
    for prop in "${!extracted_properties[@]}" ; do
        unset extracted_properties[$prop]
    done
    # initialize keys in return array (reads arguments in positions 2, 3, ...)
    for property_name ; do
        extracted_properties[$property_name]=""
    done
    comment_prefix="#";
    while IFS="" read -r line ; do
        if ! [[ $line == $comment_prefix* ]] ; then
            for prop in "${!extracted_properties[@]}" ; do
                if [[ $line =~ ^[[:space:]]*$prop[[:space:]]*=(.*) ]] ; then
                    value=${BASH_REMATCH[1]}
                    trimmed_value="$(echo -e "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
                    extracted_properties[$prop]="$trimmed_value"
                fi
            done
        fi
    done < $PROPERTIES_FILENAME
    return 0
}

# Function for alerting slack channel of any failures
function sendPreImportFailureMessageMskPipelineLogsSlack() {
    MESSAGE=$1
    curl -X POST --data-urlencode "payload={\"channel\": \"#msk-pipeline-logs\", \"username\": \"cbioportal_importer\", \"text\": \"MSK cBio pipelines pre-import process failed: $MESSAGE\", \"icon_emoji\": \":tired_face:\"}" $SLACK_PIPELINES_MONITOR_URL
}

# Function for alerting slack channel of any failures
function sendImportFailureMessageMskPipelineLogsSlack() {
    MESSAGE=$1
    curl -X POST --data-urlencode "payload={\"channel\": \"#msk-pipeline-logs\", \"username\": \"cbioportal_importer\", \"text\": \"MSK cBio pipelines import process failed: $MESSAGE\", \"icon_emoji\": \":tired_face:\"}" $SLACK_PIPELINES_MONITOR_URL
}

# Function for alerting slack channel of successful imports
function sendImportSuccessMessageMskPipelineLogsSlack() {
    STUDY_ID=$1
    curl -X POST --data-urlencode "payload={\"channel\": \"#msk-pipeline-logs\", \"username\": \"cbioportal_importer\", \"text\": \"MSK cBio pipelines import success: $STUDY_ID\", \"icon_emoji\": \":tada:\"}" $SLACK_PIPELINES_MONITOR_URL
}

# Function for alerting slack channel of clear cache failures
function sendClearCacheFailureMessage() {
    EMAIL_RECIPIENT="cbioportal-pipelines@cbio.mskcc.org"
    EMAIL_SUBJECT="import failure resetting cache $CACHE_GROUP_NAME"
    EMAIL_BODY="Imported studies may not be visible in one or more of the $CACHE_GROUP_NAME portals.\n\nImport script '$SOURCE_SCRIPT_NAME' attempted to clear/reset the persistence cache for $CACHE_GROUP_NAME portals and a failure was reported. Until a successful cache clearing occurs for these portals, studies which were successfully imported may not yet be visible.\n"
    echo -e "Sending email $EMAIL_BODY"
    echo -e "$EMAIL_BODY" | mail -s "$EMAIL_SUBJECT" "$EMAIL_RECIPIENT"
}

function printTimeStampedDataProcessingStepMessage {
    STEP_DESCRIPTION=$1
    echo -e "\n\n------------------------------------------------------------------------------------"
    echo "beginning $STEP_DESCRIPTION $(date)..."
}

# Function to generate case lists by cancer type
function addCancerTypeCaseLists {
    STUDY_DATA_DIRECTORY=$1
    STUDY_ID=$2
    # accept 1 or 2 data_clinical filenames
    FILENAME_1="$3"
    FILENAME_2="$4"
    FILEPATH_1="$STUDY_DATA_DIRECTORY/$FILENAME_1"
    FILEPATH_2="$STUDY_DATA_DIRECTORY/$FILENAME_2"
    CLINICAL_FILE_LIST="$FILEPATH_1, $FILEPATH_2"
    if [ -z "$FILENAME_2" ] ; then
        CLINICAL_FILE_LIST="$FILEPATH_1"
    fi
    # remove current case lists and run oncotree converter before creating new cancer case lists
    rm $STUDY_DATA_DIRECTORY/case_lists/*
    $PYTHON_BINARY $PORTAL_HOME/scripts/oncotree_code_converter.py --oncotree-url "http://oncotree.mskcc.org/" --oncotree-version $ONCOTREE_VERSION_TO_USE --clinical-file $FILEPATH_1 --force
    $PYTHON_BINARY $PORTAL_HOME/scripts/create_case_lists_by_cancer_type.py --clinical-file-list="$CLINICAL_FILE_LIST" --output-directory="$STUDY_DATA_DIRECTORY/case_lists" --study-id="$STUDY_ID" --attribute="CANCER_TYPE"
    if [ "$STUDY_ID" == "mskimpact" ] || [ "$STUDY_ID" == "mixedpact" ] || [ "$STUDY_ID" == "msk_solid_heme" ] ; then
       $PYTHON_BINARY $PORTAL_HOME/scripts/create_case_lists_by_cancer_type.py --clinical-file-list="$CLINICAL_FILE_LIST" --output-directory="$STUDY_DATA_DIRECTORY/case_lists" --study-id="$STUDY_ID" --attribute="PARTC_CONSENTED_12_245"
    fi
}

# Function for adding "DATE ADDED" information to clinical data
function addDateAddedData {
    STUDY_DATA_DIRECTORY=$1
    DATA_CLINICAL_FILENAME=$2
    DATA_CLINICAL_SUPP_DATE_FILENAME=$3
    # add "date added" to clinical data file
    $PYTHON_BINARY $PORTAL_HOME/scripts/update-date-added.py --date-added-file=$STUDY_DATA_DIRECTORY/$DATA_CLINICAL_SUPP_DATE_FILENAME --clinical-file=$STUDY_DATA_DIRECTORY/$DATA_CLINICAL_FILENAME
}

# Function for import project data into redcap
function import_project_to_redcap {
    FILENAME=$1
    PROJECT_TITLE=$2
    $JAVA_BINARY $JAVA_REDCAP_PIPELINE_ARGS -i --filename $FILENAME --redcap-project-title $PROJECT_TITLE
    if [ $? -gt 0 ] ; then
        #log error
        echo "Failed to import file $FILENAME into redcap project $PROJECT_TITLE"
        return 1
    fi
}

# Function for exporting redcap project
function export_project_from_redcap {
    DIRECTORY=$1
    PROJECT_TITLE=$2
    $JAVA_BINARY $JAVA_REDCAP_PIPELINE_ARGS -e -r -d $DIRECTORY --redcap-project-title $PROJECT_TITLE
    if [ $? -gt 0 ] ; then
        #log error
        echo "Failed to export project $PROJECT_TITLE from redcap into directory $DIRECTORY"
        return 1
    fi
}

# Function for exporting redcap projects (merged to standard cbioportal format) by stable id
function export_stable_id_from_redcap {
    STABLE_ID=$1
    DIRECTORY=$2
    IGNORED_PROJECTS_LIST=$3
    IGNORED_PROJECTS_ARGUMENT=""
    if [ ! -z $IGNORED_PROJECTS_LIST ] ; then
        IGNORED_PROJECTS_ARGUMENT="-m $IGNORED_PROJECTS_LIST"
    fi
    $JAVA_BINARY $JAVA_REDCAP_PIPELINE_ARGS -e -s $STABLE_ID -d $DIRECTORY $IGNORED_PROJECTS_ARGUMENT
    if [ $? -gt 0 ] ; then
        #log error
        echo "Failed to export stable_id $STABLE_ID from REDCap into directory $DIRECTORY"
        return 1
    fi
}

# Function for importing crdb files to redcap
function import_crdb_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_clinical_supp_crdb_basic.txt mskimpact_crdb_basic ; then return_value=1 ; fi
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_clinical_supp_crdb_survey.txt mskimpact_crdb_survey ; then return_value=1 ; fi
    return $return_value
}

# Function for importing mskimpact darwin files to redcap
function import_mskimpact_darwin_caisis_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_clinical_supp_caisis_gbm.txt mskimpact_clinical_caisis ; then return_value=1 ; fi
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_timeline_imaging_caisis_gbm.txt mskimpact_timeline_imaging_caisis ; then return_value=1 ; fi
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_timeline_specimen_caisis_gbm.txt mskimpact_timeline_specimen_caisis ; then return_value=1 ; fi
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_timeline_status_caisis_gbm.txt mskimpact_timeline_status_caisis ; then return_value=1 ; fi
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_timeline_surgery_caisis_gbm.txt mskimpact_timeline_surgery_caisis ; then return_value=1 ; fi
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_timeline_treatment_caisis_gbm.txt mskimpact_timeline_treatment_caisis ; then return_value=1 ; fi
    return $return_value
}

# Function for importing mskimpact cvr files to redcap
function import_mskimpact_cvr_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_clinical_mskimpact_data_clinical_cvr.txt mskimpact_data_clinical_cvr ; then return_value=1 ; fi
    return $return_value
}

# Function for importing mskimpact supp date files to redcap
function import_mskimpact_supp_date_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_clinical_mskimpact_supp_date_cbioportal_added.txt mskimpact_supp_date_cbioportal_added ; then return_value=1 ; fi
    return $return_value
}

# Function for importing mskimpact ddp files to redcap
function import_mskimpact_ddp_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_clinical_ddp.txt mskimpact_data_clinical_ddp_demographics ; then return_value=1 ; fi
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_clinical_ddp_pediatrics.txt mskimpact_data_clinical_ddp_demographics_pediatrics ; then return_value=1 ; fi
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_timeline_ddp_chemotherapy.txt mskimpact_timeline_chemotherapy_ddp; then return_value=1 ; fi
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_timeline_ddp_radiation.txt mskimpact_timeline_radiation_ddp ; then return_value=1 ; fi
    if ! import_project_to_redcap $MSK_IMPACT_DATA_HOME/data_timeline_ddp_surgery.txt mskimpact_timeline_surgery_ddp ; then return_value=1 ; fi
    return $return_value
}

# Function for importing hemepact cvr files to redcap
function import_hemepact_cvr_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_HEMEPACT_DATA_HOME/data_clinical_hemepact_data_clinical.txt hemepact_data_clinical ; then return_value=1 ; fi
    return $return_value
}

# Fucntion for importing hemepact supp date files to redcap
function import_hemepact_supp_date_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_HEMEPACT_DATA_HOME/data_clinical_hemepact_data_clinical_supp_date.txt hemepact_data_clinical_supp_date ; then return_value=1 ; fi
    return $return_value
}

# Function for import hemepact ddp files to redcap
function import_hemepact_ddp_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_HEMEPACT_DATA_HOME/data_clinical_ddp.txt hemepact_data_clinical_ddp_demographics ; then return_value=1 ; fi
    # if ! import_project_to_redcap $MSK_HEMEPACT_DATA_HOME/data_timeline_ddp_chemotherapy.txt hemepact_timeline_chemotherapy_ddp; then return_value=1 ; fi
    # if ! import_project_to_redcap $MSK_HEMEPACT_DATA_HOME/data_timeline_ddp_radiation.txt hemepact_timeline_radiation_ddp ; then return_value=1 ; fi
    # if ! import_project_to_redcap $MSK_HEMEPACT_DATA_HOME/data_timeline_ddp_surgery.txt hemepact_data_timeline_surgery_ddp ; then return_value=1 ; fi
    return $return_value
}

# Function for importing archer cvr files to redcap
function import_archer_cvr_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_ARCHER_UNFILTERED_DATA_HOME/data_clinical_mskarcher_data_clinical.txt mskarcher_data_clinical ; then return_value=1 ; fi
    return $return_value
}

# Function for importing archer supp date files to redcap
function import_archer_supp_date_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_ARCHER_UNFILTERED_DATA_HOME/data_clinical_mskarcher_data_clinical_supp_date.txt mskarcher_data_clinical_supp_date ; then return_value=1 ; fi
    return $return_value
}

# Function for import archer ddp files to redcap
function import_archer_ddp_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_ARCHER_UNFILTERED_DATA_HOME/data_clinical_ddp.txt mskarcher_data_clinical_ddp_demographics ; then return_value=1 ; fi
    # if ! import_project_to_redcap $MSK_ARCHER_UNFILTERED_DATA_HOME/data_timeline_ddp_chemotherapy.txt mskarcher_timeline_chemotherapy_ddp; then return_value=1 ; fi
    # if ! import_project_to_redcap $MSK_ARCHER_UNFILTERED_DATA_HOME/data_timeline_ddp_radiation.txt mskarcher_timeline_radiation_ddp ; then return_value=1 ; fi
    # if ! import_project_to_redcap $MSK_ARCHER_UNFILTERED_DATA_HOME/data_timeline_ddp_surgery.txt mskarcher_data_timeline_surgery_ddp ; then return_value=1 ; fi
    return $return_value
}

# Function for importing access cvr files to redcap
function import_access_cvr_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_ACCESS_DATA_HOME/data_clinical_mskaccess_data_clinical.txt mskaccess_data_clinical ; then return_value=1 ; fi
    return $return_value
}

# Function for importing access supp date files to redcap
function import_access_supp_date_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_ACCESS_DATA_HOME/data_clinical_mskaccess_data_clinical_supp_date.txt mskaccess_data_clinical_supp_date ; then return_value=1 ; fi
    return $return_value
}

# Function for import access ddp files to redcap
function import_access_ddp_to_redcap {
    return_value=0
    if ! import_project_to_redcap $MSK_ACCESS_DATA_HOME/data_clinical_ddp.txt mskaccess_data_clinical_ddp_demographics ; then return_value=1 ; fi
    # if ! import_project_to_redcap $MSK_ACCESS_DATA_HOME/data_timeline_ddp_chemotherapy.txt mskaccess_timeline_chemotherapy_ddp; then return_value=1 ; fi
    # if ! import_project_to_redcap $MSK_ACCESS_DATA_HOME/data_timeline_ddp_radiation.txt mskaccess_timeline_radiation_ddp ; then return_value=1 ; fi
    # if ! import_project_to_redcap $MSK_ACCESS_DATA_HOME/data_timeline_ddp_surgery.txt mskaccess_data_timeline_surgery_ddp ; then return_value=1 ; fi
    return $return_value
}

# Function for removing raw clinical and timeline files from study directory
function remove_raw_clinical_timeline_data_files {
    STUDY_DIRECTORY=$1
    # use rm -f and $HG_BINARY rm -f to ensure that both tracked and untracked
    # raw clinical and timeline files are removed from the repository

    # remove raw clinical files except patient and sample cbio format clinical files
    for f in $STUDY_DIRECTORY/data_clinical*; do
        if [[ $f != *"data_clinical_patient.txt"* && $f != *"data_clinical_sample.txt"* ]] ; then
            $GIT_BINARY rm -f $f
        fi
    done
    # remove raw timeline files except cbio format timeline file
    for f in $STUDY_DIRECTORY/data_timeline*; do
        if [[ $f != *"data_timeline.txt"* ]] ; then
            $GIT_BINARY rm -f $f
        fi
    done
}

# Function for filtering columns from derived studies' clinical data
function filter_derived_clinical_data {
    STUDY_DIRECTORY=$1
    $PYTHON_BINARY $PORTAL_HOME/scripts/filter_empty_columns.py --file $STUDY_DIRECTORY/data_clinical_patient.txt --keep-column-list $FILTER_EMPTY_COLUMNS_KEEP_COLUMN_LIST &&
    $PYTHON_BINARY $PORTAL_HOME/scripts/filter_empty_columns.py --file $STUDY_DIRECTORY/data_clinical_sample.txt --keep-column-list $FILTER_EMPTY_COLUMNS_KEEP_COLUMN_LIST
}

# returns the number of portals for which cache reset failed (0 = all succeeded)
function clearPersistenceCachesForPortals() {
    portal_list=$1
    exit_status=0
    for portal in $portal_list; do
        if ! $PORTAL_HOME/scripts/clear_cbioportal_persistence_cache.sh $portal ; then
            exit_status=$(($exit_status + 1))
        fi
    done
    return $exit_status
}

function clearPersistenceCachesForMskPortals() {
    all_msk_portals="msk msk-beta"
    clearPersistenceCachesForPortals "$all_msk_portals"
}

function clearPersistenceCachesForExternalPortals() {
    all_external_portals="acc glioma immunotherapy kras pdx poetic private prostate sclc su2c target"
    clearPersistenceCachesForPortals "$all_external_portals"
}

function clearPersistenceCachesForTriagePortals() {
    all_triage_portals="triage"
    clearPersistenceCachesForPortals "$all_triage_portals"
}

function clearPersistenceCachesForPublicPortals() {
    all_public_portals="public"
    clearPersistenceCachesForPortals "$all_public_portals"
}

function clearPersistenceCachesForGeniePortals() {
    all_genie_portals="genie-public genie-private"
    clearPersistenceCachesForPortals "$all_genie_portals"
}

function clearPersistenceCachesForGenieArchivePortals() {
    all_genie_archive_portals="genie-archive"
    clearPersistenceCachesForPortals "$all_genie_archive_portals"
}

# Function for consuming fetched samples after successful import
function consumeSamplesAfterSolidHemeImport {
    if [ -f $MSK_IMPACT_CONSUME_TRIGGER ] ; then
        echo "Consuming mskimpact samples from cvr"
        $JAVA_BINARY $JAVA_CVR_FETCHER_ARGS -c $MSK_IMPACT_DATA_HOME/cvr_data.json
        $JAVA_BINARY $JAVA_CVR_FETCHER_ARGS -g -c $MSK_IMPACT_DATA_HOME/cvr_gml_data.json
        rm -f $MSK_IMPACT_CONSUME_TRIGGER
    fi
    if [ -f $MSK_HEMEPACT_CONSUME_TRIGGER ] ; then
        echo "Consuming mskimpact_heme samples from cvr"
        $JAVA_BINARY $JAVA_CVR_FETCHER_ARGS -c $MSK_HEMEPACT_DATA_HOME/cvr_data.json
        rm -f $MSK_HEMEPACT_CONSUME_TRIGGER
    fi
    if [ -f $MSK_ACCESS_CONSUME_TRIGGER ] ; then
        echo "Consuming mskaccess samples from cvr"
        $JAVA_BINARY $JAVA_CVR_FETCHER_ARGS -c $MSK_ACCESS_DATA_HOME/cvr_data.json
        rm -f $MSK_ACCESS_CONSUME_TRIGGER
    fi
}

# Function for consuming fetched samples after successful archer import
function consumeSamplesAfterArcherImport {
    if [ -f $MSK_ARCHER_CONSUME_TRIGGER ] ; then
        echo "Consuming archer samples from cvr"
        $JAVA_BINARY $JAVA_CVR_FETCHER_ARGS -c $MSK_ARCHER_UNFILTERED_DATA_HOME/cvr_data.json
        rm -f $MSK_ARCHER_CONSUME_TRIGGER
    fi
}
