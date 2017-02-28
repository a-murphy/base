update projects set "isOrphaned" = false where "isOrphaned" is NULL;
create temp table temp_pa as select id from projects;
delete from temp_pa using "projectAccounts" where "projectAccounts"."projectId" = temp_pa.id;
update projects set "isOrphaned" = true from temp_pa where temp_pa.id = projects.id;
drop table temp_pa;

-- Migration Script to populate jobstatesMap for runs
create temp table tjsm as WITH cte AS
(
   SELECT "id","projectId","branchName","runNumber","createdAt","statusCode","isGitTag","isPullRequest","isRelease","gitTagName","releaseName","subscriptionId", "createdBy", "updatedBy", "updatedAt", ROW_NUMBER() OVER (PARTITION BY "projectId","branchName","statusCode","isGitTag","isPullRequest","isRelease" ORDER BY "createdAt" desc)
AS rn FROM runs WHERE "statusCode" in (30,50,60,80) and "branchName" is not null
)
SELECT "id", "projectId" as pid,"branchName" as bn,"runNumber","createdAt","statusCode","isGitTag","isPullRequest","isRelease","gitTagName","releaseName","subscriptionId", "createdBy", "updatedBy", "updatedAt"
FROM cte
WHERE rn = 1;

-- add required columns to temp table tjsm
alter table tjsm add column "contextTypeCode" int, add column "contextValue" varchar(255), add column "lastSuccessfulJobId" varchar(24), add column "lastFailedJobId" varchar(24), add column "lastUnstableJobId" varchar(24), add column "lastTimedoutJobId" varchar(24);

-- update null fields
update tjsm T set "isPullRequest" = false where "isPullRequest" is null;
update tjsm T set "isGitTag" = false where "isGitTag" is null;
update tjsm T set "isRelease" = false where "isRelease" is null;
update tjsm T set "releaseName" = T."gitTagName" where "isRelease" = true and "releaseName" is null;

-- update contextTypeCode, contextValue
update tjsm set "contextTypeCode" = 301, "contextValue" = tjsm."gitTagName" where "isGitTag" = true;
update tjsm set "contextTypeCode" = 302, "contextValue" = tjsm."releaseName" where "isRelease" = true;
update tjsm set "contextTypeCode" = 303, "contextValue" = tjsm.bn where "isPullRequest" = true;
update tjsm set "contextTypeCode" = 304, "contextValue" = tjsm.bn where "isPullRequest" = false and "isGitTag" = false and "isRelease" = false;
update tjsm set "updatedBy" = tjsm."createdBy" where "updatedBy" is null;

-- update lastSuccessfulJobId, lastUnstableJobId, lastTimedoutJobId, lastFailedJobId
update tjsm T1 set "lastSuccessfulJobId" = T2.id from tjsm T2 where T1."contextTypeCode" = T2."contextTypeCode" and T1."contextValue" = T2."contextValue" and T1.pid = T2.pid and T2."statusCode" = 30;

update tjsm T1 set "lastUnstableJobId" = T2.id from tjsm T2 where T1."contextTypeCode" = T2."contextTypeCode" and T1."contextValue" = T2."contextValue" and T1.pid = T2.pid and T2."statusCode" = 50;

update tjsm T1 set "lastTimedoutJobId" = T2.id from tjsm T2 where T1."contextTypeCode" = T2."contextTypeCode" and T1."contextValue" = T2."contextValue" and T1.pid = T2.pid and T2."statusCode" = 60;

update tjsm T1 set "lastFailedJobId" = T2.id from tjsm T2 where T1."contextTypeCode" = T2."contextTypeCode" and T1."contextValue" = T2."contextValue" and T1.pid = T2.pid and T2."statusCode" = 80;

-- creating a temp table temptjsm which have only latest records
create temp table temptjsm as WITH cte AS
(
   SELECT id,pid,"createdAt","contextTypeCode","contextValue","statusCode","subscriptionId", "createdBy", "updatedBy", "updatedAt","lastSuccessfulJobId","lastUnstableJobId","lastTimedoutJobId","lastFailedJobId", ROW_NUMBER() OVER (PARTITION BY "pid","contextTypeCode","contextValue" ORDER BY "createdAt" desc)
AS rn FROM tjsm
)
SELECT "id",pid,"createdAt","statusCode","contextTypeCode","contextValue","lastSuccessfulJobId","lastUnstableJobId","lastTimedoutJobId","lastFailedJobId","subscriptionId", "createdBy", "updatedBy", "updatedAt"
FROM cte
WHERE rn = 1;

truncate "jobStatesMap";

INSERT INTO "jobStatesMap" ("projectId", "subscriptionId", "jobTypeCode", "contextTypeCode", "contextValue", "lastSuccessfulJobId", "lastUnstableJobId", "lastTimedoutJobId", "lastFailedJobId", "lastJobId", "createdBy", "updatedBy", "updatedAt", "createdAt")
SELECT pid,"subscriptionId", 201, "contextTypeCode", "contextValue", "lastSuccessfulJobId", "lastUnstableJobId", "lastTimedoutJobId", "lastFailedJobId", id, "createdBy", "updatedBy", "updatedAt", "createdAt" FROM temptjsm;

drop table tjsm;
drop table temptjsm;


-- Migration Script to populate jobstatesMap for builds

create temp table tjsm as WITH cte AS
(
   SELECT "id","projectId","resourceId","createdAt","statusCode","subscriptionId", "updatedAt", ROW_NUMBER() OVER (PARTITION BY "projectId","resourceId", "statusCode" ORDER BY "createdAt" desc)
AS rn FROM builds WHERE "statusCode" in (4002,4003)
)
SELECT "id","projectId" as pid,"resourceId" as rid,"createdAt","statusCode","subscriptionId", "updatedAt"
FROM cte
WHERE rn = 1;

create temp table rtjsm as WITH cte AS
(
   SELECT "id","projectId","createdAt", "createdBy", "updatedBy","name","typeCode","isJob" FROM resources WHERE "isJob" = true and "typeCode" in (2010,2000,2005,2007,2012,2011,2009)
)
SELECT "id","projectId" as rpid,"createdAt", "createdBy", "updatedBy","name" as "contextValue","typeCode" as "contextTypeCode"
FROM cte;

-- add required columns to temp table tjsm
alter table tjsm add column "contextValue" varchar(255), add column "contextTypeCode" int, add column "lastSuccessfulJobId" varchar(24), add column "lastFailedJobId" varchar(24), add column "createdBy" varchar(24), add column "updatedBy" varchar(24);

-- update contextTypeCode, contextValue
update rtjsm set "contextTypeCode" = 305 where "contextTypeCode" = 2010;
update rtjsm set "contextTypeCode" = 306 where "contextTypeCode" = 2000;
update rtjsm set "contextTypeCode" = 307 where "contextTypeCode" = 2005;
update rtjsm set "contextTypeCode" = 308 where "contextTypeCode" = 2007;
update rtjsm set "contextTypeCode" = 309 where "contextTypeCode" = 2012;
update rtjsm set "contextTypeCode" = 310 where "contextTypeCode" = 2011;
update rtjsm set "contextTypeCode" = 311 where "contextTypeCode" = 2009;

update tjsm T1 set "contextValue" = T2."contextValue" from rtjsm T2 where T1.rid = T2.id;
update tjsm T1 set "contextTypeCode" = T2."contextTypeCode" from rtjsm T2 where T1.rid = T2.id;
update tjsm T1 set "createdBy" = T2."createdBy" from rtjsm T2 where T1.rid = T2.id;
update tjsm T1 set "updatedBy" = T2."updatedBy" from rtjsm T2 where T1.rid = T2.id;

-- ignoring records which are not part of (2010,2000,2005,2007,2012,2011,2009) typeCodes
delete from tjsm where "contextValue" is null;

-- update lastSuccessfulJobId, lastFailedJobId
update tjsm T1 set "lastSuccessfulJobId" = T2.id from tjsm T2 where T1."contextTypeCode" = T2."contextTypeCode" and T1."contextValue" = T2."contextValue" and T1.pid = T2.pid and T2."statusCode" = 4002 and T1.rid = T2.rid;

update tjsm T1 set "lastFailedJobId" = T2.id from tjsm T2 where T1."contextTypeCode" = T2."contextTypeCode" and T1."contextValue" = T2."contextValue" and T1.pid = T2.pid and T2."statusCode" = 4003 and T1.rid = T2.rid;

-- creating a temp table temptjsm which have only latest records
create temp table temptjsm as WITH cte AS
(
   SELECT id,pid,"createdAt","contextTypeCode","contextValue","statusCode","subscriptionId", "createdBy", "updatedBy", "updatedAt","lastSuccessfulJobId","lastFailedJobId", ROW_NUMBER() OVER (PARTITION BY "pid","contextTypeCode","contextValue" ORDER BY "createdAt" desc)
AS rn FROM tjsm
)
SELECT "id",pid,"createdAt","statusCode","contextTypeCode","contextValue","lastSuccessfulJobId","lastFailedJobId","subscriptionId", "createdBy", "updatedBy", "updatedAt"
FROM cte
WHERE rn = 1;

INSERT INTO "jobStatesMap" ("projectId", "subscriptionId", "jobTypeCode", "contextTypeCode", "contextValue", "lastSuccessfulJobId", "lastFailedJobId", "lastJobId", "createdBy", "updatedBy", "updatedAt", "createdAt")
SELECT pid,"subscriptionId", 202, "contextTypeCode", "contextValue", "lastSuccessfulJobId", "lastFailedJobId", id, "createdBy", "updatedBy", "updatedAt", "createdAt" FROM temptjsm;

drop table tjsm;
drop table rtjsm;
drop table temptjsm;
