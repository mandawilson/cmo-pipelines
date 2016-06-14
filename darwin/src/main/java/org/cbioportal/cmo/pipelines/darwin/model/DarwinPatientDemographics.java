/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package org.cbioportal.cmo.pipelines.darwin.model;

import java.util.*;
import org.apache.commons.lang.builder.ToStringBuilder;

/**
 *
 * @author jake
 */
public class DarwinPatientDemographics {

    private String PT_ID_DEMO;
    private String DMP_ID_DEMO;
    private String GENDER;
    private String RACE;
    private String RELIGION;
    private String AGE_AT_DATE_OF_DEATH_IN_DAYS;
    private String DEATH_SOURCE_DESCRIPTION;
    private String VITAL_STATUS;
    private String PT_COUNTRY;
    private String PT_STATE;
    private String PT_ZIP3_CD;
    private String PT_BIRTH_YEAR;
    private String PT_SEX_DESC;
    private String PT_VITAL_STATUS;
    private String PT_MARITAL_STS_DESC;
    private String PT_DEATH_YEAR;
    private String PT_MRN_CREATE_YEAR;
    private Map<String, Object> additionalProperties = new HashMap<>();

    public DarwinPatientDemographics() {
    }

    public DarwinPatientDemographics(String PT_ID_DEMO, String DMP_ID_DEMO, String GENDER,
            String RACE, String RELIGION, String AGE_AT_DATE_OF_DEATH_IN_DAYS, String DEATH_SOURCE_DESCRIPTION, String VITAL_STATUS,
            String PT_COUNTRY, String PT_STATE, String PT_ZIP3_CD, String PT_BIRTH_YEAR, String PT_SEX_DESC,
            String PT_VITAL_STATUS, String PT_MARITAL_STS_DESC, String PT_DEATH_YEAR, String PT_MRN_CREATE_YEAR) {
        this.PT_ID_DEMO = PT_ID_DEMO != null ? PT_ID_DEMO : "";
        this.DMP_ID_DEMO = DMP_ID_DEMO != null ? DMP_ID_DEMO : "";
        this.GENDER = GENDER != null ? GENDER : "";
        this.RACE = RACE != null ? RACE : "";
        this.RELIGION = RELIGION != null ? RELIGION : "";
        this.AGE_AT_DATE_OF_DEATH_IN_DAYS = AGE_AT_DATE_OF_DEATH_IN_DAYS != null ? AGE_AT_DATE_OF_DEATH_IN_DAYS : "";
        this.DEATH_SOURCE_DESCRIPTION = DEATH_SOURCE_DESCRIPTION != null ? DEATH_SOURCE_DESCRIPTION : "";
        this.VITAL_STATUS = VITAL_STATUS != null ? VITAL_STATUS : "";
        this.PT_COUNTRY = PT_COUNTRY != null ? PT_COUNTRY : "";
        this.PT_STATE = PT_STATE != null ? PT_STATE : "";
        this.PT_ZIP3_CD = PT_ZIP3_CD != null ? PT_ZIP3_CD : "";
        this.PT_BIRTH_YEAR = PT_BIRTH_YEAR != null ? PT_BIRTH_YEAR : "";
        this.PT_SEX_DESC = PT_SEX_DESC != null ? PT_SEX_DESC : "";
        this.PT_VITAL_STATUS = PT_VITAL_STATUS != null ? PT_VITAL_STATUS : "";
        this.PT_MARITAL_STS_DESC = PT_MARITAL_STS_DESC != null ? PT_MARITAL_STS_DESC : "";
        this.PT_DEATH_YEAR = PT_DEATH_YEAR != null ? PT_DEATH_YEAR : "";
        this.PT_MRN_CREATE_YEAR = PT_MRN_CREATE_YEAR != null ? PT_MRN_CREATE_YEAR : "";
    }

    public String getPT_ID_DEMO() {
        return PT_ID_DEMO;
    }

    public void setPT_ID_DEMO(String PT_ID_DEMO) {
        this.PT_ID_DEMO = PT_ID_DEMO != null ? PT_ID_DEMO : "";
    }

    public String getDMP_ID_DEMO() {
        return DMP_ID_DEMO;
    }

    public void setDMP_ID_DEMO(String DMP_ID_DEMO) {
        this.DMP_ID_DEMO = DMP_ID_DEMO != null ? DMP_ID_DEMO : "";
    }

    public String getGENDER() {
        return GENDER;
    }

    public void setGENDER(String GENDER) {
        this.GENDER = GENDER != null ? GENDER : "";
    }

    public String getRACE() {
        return RACE;
    }

    public void setRACE(String RACE) {
        this.RACE = RACE != null ? RACE : "";
    }

    public String getRELIGION() {
        return RELIGION;
    }

    public void setRELIGION(String RELIGION) {
        this.RELIGION = RELIGION != null ? RELIGION : "";
    }

    public String getAGE_AT_DATE_OF_DEATH_IN_DAYS() {
        return AGE_AT_DATE_OF_DEATH_IN_DAYS;
    }

    public void setAGE_AT_DATE_OF_DEATH_IN_DAYS(String AGE_AT_DATE_OF_DEATH_IN_DAYS) {
        this.AGE_AT_DATE_OF_DEATH_IN_DAYS = AGE_AT_DATE_OF_DEATH_IN_DAYS != null ? AGE_AT_DATE_OF_DEATH_IN_DAYS : "";
    }

    public String getDEATH_SOURCE_DESCRIPTION() {
        return DEATH_SOURCE_DESCRIPTION;
    }

    public void setDEATH_SOURCE_DESCRIPTION(String DEATH_SOURCE_DESCRIPTION) {
        this.DEATH_SOURCE_DESCRIPTION = DEATH_SOURCE_DESCRIPTION != null ? DEATH_SOURCE_DESCRIPTION : "";
    }
    
    public String getVITAL_STATUS(){
        return VITAL_STATUS;
    }
    
    public void setVITAL_STATUS(){
        this.VITAL_STATUS = VITAL_STATUS != null ? VITAL_STATUS : "";
    }

    public String getPT_COUNTRY() {
        return PT_COUNTRY;
    }

    public void setPT_COUNTRY(String PT_COUNTRY) {
        this.PT_COUNTRY = PT_COUNTRY != null ? PT_COUNTRY : "";
    }

    public String getPT_STATE() {
        return PT_STATE;
    }

    public void setPT_STATE(String PT_STATE) {
        this.PT_STATE = PT_STATE != null ? PT_STATE : "";
    }

    public String getPT_ZIP3_CD() {
        return PT_ZIP3_CD;
    }

    public void setPT_ZIP3_CD(String PT_ZIP3_CD) {
        this.PT_ZIP3_CD = PT_ZIP3_CD != null ? PT_ZIP3_CD : "";
    }

    public String getPT_BIRTH_YEAR() {
        return PT_BIRTH_YEAR;
    }

    public void setPT_BIRTH_YEAR(String PT_BIRTH_YEAR) {
        this.PT_BIRTH_YEAR = PT_BIRTH_YEAR != null ? PT_BIRTH_YEAR : "";
    }

    public String getPT_SEX_DESC() {
        return PT_SEX_DESC;
    }

    public void setPT_SEX_DESC(String PT_SEX_DESC) {
        this.PT_SEX_DESC = PT_SEX_DESC != null ? PT_SEX_DESC : "";
    }

    public String getPT_VITAL_STATUS() {
        return PT_VITAL_STATUS;
    }

    public void setPT_VITAL_STATUS(String PT_VITAL_STATUS) {
        this.PT_VITAL_STATUS = PT_VITAL_STATUS != null ? PT_VITAL_STATUS : "";
    }

    public String getPT_MARITAL_STS_DESC() {
        return PT_MARITAL_STS_DESC;
    }

    public void setPT_MARITAL_STS_DESC(String PT_MARITAL_STS_DESC) {
        this.PT_MARITAL_STS_DESC = PT_MARITAL_STS_DESC != null ? PT_MARITAL_STS_DESC : "";
    }

    public String getPT_DEATH_YEAR() {
        return PT_DEATH_YEAR;
    }

    public void setPT_DEATH_YEAR(String PT_DEATH_YEAR) {
        this.PT_DEATH_YEAR = PT_DEATH_YEAR != null ? PT_DEATH_YEAR : "";
    }

    public String getPT_MRN_CREATE_YEAR() {
        return PT_MRN_CREATE_YEAR;
    }

    public void setPT_MRN_CREATE_YEAR(String PT_MRN_CREATE_YEAR) {
        this.PT_MRN_CREATE_YEAR = PT_MRN_CREATE_YEAR != null ? PT_MRN_CREATE_YEAR : "";
    }

    @Override
    public String toString() {
        return ToStringBuilder.reflectionToString(this);
    }

    public List<String> getFieldNames() {
        List<String> fieldNames = new ArrayList<>();
        fieldNames.add("PT_ID_DEMO");
        fieldNames.add("DMP_ID_DEMO");
        fieldNames.add("GENDER");
        fieldNames.add("RACE");
        fieldNames.add("RELIGION");
        fieldNames.add("AGE_AT_DATE_OF_DEATH_IN_DAYS");
        fieldNames.add("DEATH_SOURCE_DESCRIPTION");
        fieldNames.add("VITAL_STATUS");
        fieldNames.add("PT_COUNTRY");
        fieldNames.add("PT_STATE");
        fieldNames.add("PT_ZIP3_CD");
        fieldNames.add("PT_BIRTH_YEAR");
        fieldNames.add("PT_SEX_DESC");
        fieldNames.add("PT_VITAL_STATUS");
        fieldNames.add("PT_MARITAL_STS_DESC");
        fieldNames.add("PT_DEATH_YEAR");
        fieldNames.add("PT_MRN_CREATE_YEAR");

        return fieldNames;

    }

    public void setAdditionalProperty(String name, Object value) {
        this.additionalProperties.put(name, value);
    }

    public Map<String, Object> getAdditionalProperties() {
        return this.additionalProperties;
    }

}
