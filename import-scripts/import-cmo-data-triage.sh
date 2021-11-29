#!/usr/bin/env bash

FLOCK_FILEPATH="/data/portal-cron/cron-lock/import-cmo-data-triage.lock"
(
    echo $(date)

    # check lock so that script executions do not overlap
    if ! flock --nonblock --exclusive $flock_fd ; then
        exit 0
    fi

    # set necessary env variables with automation-environment.sh

    # we need this file for the clear persistence cache functions
    source $PORTAL_HOME/scripts/dmp-import-vars-functions.sh
    # set data source env variables
    source $PORTAL_HOME/scripts/set-data-source-environment-vars.sh

    tmp=$PORTAL_HOME/tmp/import-cron-cmo-triage
    if ! [ -d "$tmp" ] ; then
        if ! mkdir -p "$tmp" ; then
            echo "Error : could not create tmp directory '$tmp'" >&2
            exit 1
        fi
    fi
    if [[ -d "$tmp" && "$tmp" != "/" ]]; then
        rm -rf "$tmp"/*
    fi
    now=$(date "+%Y-%m-%d-%H-%M-%S")
    IMPORTER_JAR_FILENAME="$PORTAL_HOME/lib/triage-cmo-importer.jar"
    java_debug_args=""
    ENABLE_DEBUGGING=0
    if [ $ENABLE_DEBUGGING != "0" ] ; then
        java_debug_args="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=27183"
    fi
    JAVA_IMPORTER_ARGS="$JAVA_PROXY_ARGS $java_debug_args $JAVA_SSL_ARGS -Dspring.profiles.active=dbcp -Djava.io.tmpdir=$tmp -ea -cp $IMPORTER_JAR_FILENAME org.mskcc.cbio.importer.Admin"
    triage_notification_file=$(mktemp $tmp/triage-portal-update-notification.$now.XXXXXX)
    ONCOTREE_VERSION_TO_USE=oncotree_candidate_release
    DATA_SOURCES_TO_BE_FETCHED="bic-mskcc cmo-argos private impact impact-MERGED knowledge-systems-curated-studies immunotherapy datahub datahub_shahlab msk-mind-datahub pipelines-testing"
    unset failed_data_source_fetches
    declare -a failed_data_source_fetches

    CDD_ONCOTREE_RECACHE_FAIL=0
    if ! [ -z $INHIBIT_RECACHING_FROM_TOPBRAID ] ; then
        # refresh cdd and oncotree cache
        bash $PORTAL_HOME/scripts/refresh-cdd-oncotree-cache.sh
        if [ $? -gt 0 ]; then
            CDD_ONCOTREE_RECACHE_FAIL=1
            message="Failed to refresh CDD and/or ONCOTREE cache during TRIAGE import!"
            echo $message
            echo -e "$message" | mail -s "CDD and/or ONCOTREE cache failed to refresh" $PIPELINES_EMAIL_LIST
        fi
    fi

    # fetch updates to data source repos
    fetch_updates_in_data_sources $DATA_SOURCES_TO_BE_FETCHED

    # import data that requires QC into triage portal
    echo "importing cancer type updates into triage portal database..."
    $JAVA_BINARY -Xmx16g $JAVA_IMPORTER_ARGS --import-types-of-cancer --oncotree-version ${ONCOTREE_VERSION_TO_USE}

    DB_VERSION_FAIL=0
    # check database version before importing anything
    echo "Checking if database version is compatible"
    $JAVA_BINARY $JAVA_IMPORTER_ARGS --check-db-version
    if [ $? -gt 0 ]
    then
        echo "Database version expected by portal does not match version in database!"
        DB_VERSION_FAIL=1
    fi

    # if the database version is correct and ALL fetches succeed, then import
    if [[ $DB_VERSION_FAIL -eq 0 && ${#failed_data_source_fetches[*]} -eq 0 && $CDD_ONCOTREE_RECACHE_FAIL -eq 0 ]] ; then
        echo "importing study data into triage portal database..."
        IMPORT_FAIL=0
        $JAVA_BINARY -Xmx32G $JAVA_IMPORTER_ARGS --update-study-data --portal triage-portal --use-never-import --update-worksheet --notification-file "$triage_notification_file" --oncotree-version ${ONCOTREE_VERSION_TO_USE} --transcript-overrides-source mskcc
        if [ $? -gt 0 ]; then
            echo "Triage import failed!"
            IMPORT_FAIL=1
            EMAIL_BODY="Triage import failed"
            echo -e "Sending email $EMAIL_BODY"
            echo -e "$EMAIL_BODY" | mail -s "Import failure: triage" $PIPELINES_EMAIL_LIST
        fi
        num_studies_updated=`cat $tmp/num_studies_updated.txt`

        # clear persistence cache
        if [[ $IMPORT_FAIL -eq 0 && $num_studies_updated -gt 0 ]]; then
            echo "'$num_studies_updated' studies have been updated, clearing persistence cache for triage portal..."
            if ! clearPersistenceCachesForTriagePortals ; then
                sendClearCacheFailureMessage triage import-cmo-data-triage.sh
            fi
        else
            echo "No studies have been updated, not clearing persitsence cache for triage portal..."
        fi

        # import ran and either failed or succeeded
        echo "sending notification email.."
        $JAVA_BINARY $JAVA_IMPORTER_ARGS --send-update-notification --portal triage-portal --notification-file "$triage_notification_file"
    fi

    EMAIL_BODY="The Triage database version is incompatible. Imports will be skipped until database is updated."
    # send email if db version isn't compatible
    if [ $DB_VERSION_FAIL -gt 0 ]
    then
        echo -e "Sending email $EMAIL_BODY"
        echo -e "$EMAIL_BODY" | mail -s "Triage Update Failure: DB version is incompatible" $CMO_EMAIL_LIST
    fi

    echo "Cleaning up any untracked files from MSK-TRIAGE import..."
    bash $PORTAL_HOME/scripts/datasource-repo-cleanup.sh $PORTAL_DATA_HOME $PORTAL_DATA_HOME/bic-mskcc $PORTAL_DATA_HOME/cmo-argos $PORTAL_DATA_HOME/private $PORTAL_DATA_HOME/impact $PORTAL_DATA_HOME/immunotherapy $PORTAL_DATA_HOME/datahub $PORTAL_DATA_HOME/datahub_shahlab $PORTAL_DATA_HOME/msk-mind $PORTAL_DATA_HOME/pipelines-testing
) {flock_fd}>$FLOCK_FILEPATH
