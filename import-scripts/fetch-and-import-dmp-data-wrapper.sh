#!/bin/bash

date
echo executing fetch-dmp-data-for-import.sh
/data/portal-cron/scripts/fetch-dmp-data-for-import.sh
date
echo executing import-dmp-impact-data.sh
/data/portal-cron/scripts/import-dmp-impact-data.sh
date
echo executing oncokb-annotator.sh on MSKSOLIDHEME
/data/portal-cron/scripts/oncokb-annotator.sh
date
echo executing import-pdx-data.sh
/data/portal-cron/scripts/import-pdx-data.sh
#TODO: fix import into AWS GDAC - speed up import time 
#date
#echo executing import-gdac-aws-data.sh
#/data/portal-cron/scripts/import-gdac-aws-data.sh
date
echo executing update-msk-extract-cohort.sh
/data/portal-cron/scripts/update-msk-extract-cohort.sh
date
echo executing update-msk-spectrum-cohort.sh
/data/portal-cron/scripts/update-msk-spectrum-cohort.sh
date
echo wrapper complete
