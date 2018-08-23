# Rashmit : 16200161
# Project on Marriages and Divorces database

# Drop database if already exists
drop database if exists marriage_divorce_DB;
# Create database if not exists
create database if not exists marriage_divorce_DB;
# Use database we created just now
use marriage_divorce_DB;

# Table: Religion
# Primary Key: religionId
create table Religion(
	religionId int NOT NULL,
	religionName varchar(45) NOT NULL,
	allowedNumOfMarriages int NOT NULL,
	primary key(religionId)
);

# Table: MarriageDetails
# Primary Key: marriageCertificateNum
create table MarriageDetails(
	marriageCertificateNum int NOT NULL,
	dateOfMarriage date NOT NULL,
	countryOfMarriage varchar(45) NOT NULL,
	primary key(marriageCertificateNum)
);

# Table: DivorceDetails
# Primary Key: divorceNumber
# Foreign Key: marriageCertificateNum
create table DivorceDetails(
	divorceNumber int NOT NULL,
	marriageCertificateNum int NOT NULL,
	dateOfDivorce date NOT NULL,
	countryOfDivorce varchar(45) NOT NULL,
	primary key(divorceNumber),
	foreign key(marriageCertificateNum) REFERENCES MarriageDetails(marriageCertificateNum)
);

# Table: Nationality
# Primary Key: nationalityId
create table Nationality(
	nationalityId int NOT NULL,
	country varchar(45) NOT NULL,
	primary key(nationalityId)
);

# Table: PersonDetails
# Primary Key: personId
# Foreign Key: religionId
create table PersonDetails(
	personId int NOT NULL,
	religionId int NOT NULL,
	firstName varchar(45) NOT NULL,
	lastName varchar(45) NOT NULL,
	gender varbinary(1) NOT NULL,
	age int NOT NULL,
	primary key(personId),
	foreign key(religionId) REFERENCES Religion(religionId)
);

# Table: DeathDetails
# Primary Key: deathId
# Foreign Key: personId
create table DeathDetails(
	deathId int NOT NULL,
	personId int NOT NULL,
	dateOfDeath date NOT NULL,
	reasonOfDeath varchar(100),
	primary key(deathId),
	foreign key(personId) REFERENCES PersonDetails(personId)
);

# Table: PersonNationality
# Primary Key: personNationalityId
# Foreign Key: personId
# Foreign Key: nationalityId
create table PersonNationality(
	personNationalityId int NOT NULL,
	personId int NOT NULL,
	nationalityId int NOT NULL,
	primary key(personNationalityId),
	foreign key(personId) REFERENCES PersonDetails(personId),
	foreign key(nationalityId) REFERENCES Nationality(nationalityId)
);

# Table: PersonInMarriage
# Primary Key: personInMarriageId
# Foreign Key: personId
# Foreign Key: marriageCertificateNum
create table PersonInMarriage(
	personInMarriageId int NOT NULL,
	personId int NOT NULL,
	marriageCertificateNum int NOT NULL,
	status varbinary(1) NOT NULL,
	primary key(personInMarriageId),
	foreign key(personId) REFERENCES PersonDetails(personId),
	foreign key(marriageCertificateNum) REFERENCES MarriageDetails(marriageCertificateNum)
);


# Trigger: To check if age of a person is greater than or equal to 18
delimiter $$
create trigger ageCheck before insert on PersonDetails 
	for each row 
	begin
	# Disallow people in PersonDetails who are younger than 18 years of age
  	if NEW.age < 18 then
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "age should be > 18.";
  end if; 
end; $$
delimiter ;


# Trigger: Update status of partners in PersonInMarriage to "N" after death.
delimiter $$
create trigger afterDeath after insert on DeathDetails
for each row 
begin
declare mID int;
# On insertion of persionId into DeathDetails, fetch that personID to get marriageCertificateNum
# Convert status of people associated with this marriageCertificateNum to "N"
select marriageCertificateNum into mID from PersonInMarriage where PersonInMarriage.personId = NEW.personId;
update PersonInMarriage set PersonInMarriage.status = 'N' where PersonInMarriage.marriageCertificateNum = mID;
end; $$
delimiter ;


# Trigger: Check if divorce place is same as marriage place 
# and divorce date is after marriage date

delimiter $$
create trigger beforeDivorce before insert on DivorceDetails 
for each row 
begin
declare com varchar(45);
declare dom date;

# Fetch the place of marriage of a person based on marriageCertificateNum. 
# Restrict divorce if place of divorce is different than place of marriage.
select countryOfMarriage into com from MarriageDetails where NEW.marriageCertificateNum = MarriageDetails.marriageCertificateNum;
select dateOfMarriage into dom from MarriageDetails where NEW.marriageCertificateNum = MarriageDetails.marriageCertificateNum;

if NEW.countryOfDivorce != com then
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Divorce place must be same as Marriage Place.";
end if; 

if NEW.dateOfDivorce < dom then
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Divorce cannot happen before marriage";
end if; 

end; $$
delimiter ;


# Trigger: Update status of partners in PersonInMarriage to "N" after divorce.
delimiter $$
create trigger afterDivorce before insert on DivorceDetails 
for each row 
begin
# Convert status of people associated with this marriageCertificateNum to "N"
update PersonInMarriage set PersonInMarriage.status = 'N' where PersonInMarriage.marriageCertificateNum = NEW.marriageCertificateNum;
end; $$
delimiter ;


# Trigger: Check marriage eligibility before insertion in PersonInMarriage
delimiter $$
create trigger marriageCount before insert on PersonInMarriage
for each row
begin
declare rn int;
declare am int;
declare cms int;
declare cn1 varchar(45);
declare d int;


# get the count of marriages allowed in a religion of person
select religionId into rn from PersonDetails where PersonDetails.personId = NEW.personId;
select allowedNumOfMarriages into am from Religion where Religion.religionId = rn;
select count(status) into cms from PersonInMarriage where PersonInMarriage.personId = NEW.personId and PersonInMarriage.status = "Y";

# get the country of marriage of person
select countryOfMarriage into cn1 from MarriageDetails where marriageCertificateNum IN (select marriageCertificateNum from PersonInMarriage where personId = NEW.personId);

# get the personId from DeathDetails
select deathId into d from DeathDetails where DeathDetails.personId =  NEW.personId;

# check if number of marriages allowed in religion is equals to current number of marriage relationships
# it it is equal, restrict person to marry again.
if cms = am then
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Allowed limit exceeded.";
end if;

# check if nationality of the person is equal to the marriage place
# if not, then restrict marriage based on nationality issues.
if cn1 NOT IN (select country from Nationality where nationalityId IN (select nationalityId from PersonNationality where personId = NEW.personId)) then
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Nationality Issue";
end if;

# check if dead personId present
# if present, restrict dead person to get marry.
if d != NULL then
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Person is dead";
end if;
end; $$
delimiter ;

#Insert Religion_Details
insert into Religion values(1,'Bhuddism',1);
insert into Religion values(2,'Sikhism',1);
insert into Religion values(3,'Jainism',1);
insert into Religion values(4,'Christianity',1);
insert into Religion values(5,'Muslim',4);
insert into Religion values(6,'Hinduism',1);

#Insert Nationality_Details
insert into Nationality values(1,'Ireland');
insert into Nationality values(2,'India');
insert into Nationality values(3,'Ukraine');
insert into Nationality values(4,'England');
insert into Nationality values(5,'Pakistan');
insert into Nationality values(6,'Nepal');
insert into Nationality values(7,'Bhutan');
insert into Nationality values(8,'China');
insert into Nationality values(9,'German');
insert into Nationality values(10,'Scotland');

#Insert PersonDetails
insert into PersonDetails values(1,2, 'Andreas','Themis','M',37);
insert into PersonDetails values(2,3, 'Harbajan','Singh','M',28);
insert into PersonDetails values(3,4, 'King','Henry','M',37);	
insert into PersonDetails values(4,4, 'Richard', 'Burton','M',20);	
insert into PersonDetails values(5,4, 'Elizabeth', 'Taylor','M',20);
insert into PersonDetails values(11,3, 'Meena','Kaur','F',32);
insert into PersonDetails values(12,5, 'Faiza','Begum','F',22);
insert into PersonDetails values(13,5, 'Mohammad','Khan','M',22);
insert into PersonDetails values(19,1, 'Rahul','Dravid','M',37);

# Insert Personality Nationality
insert into PersonNationality values(1,1,2);
insert into PersonNationality values(2,19,3);
insert into PersonNationality values(3,2,3);
insert into PersonNationality values(4,3,3);
insert into PersonNationality values(5,4,5);
insert into PersonNationality values(6,5,2);
insert into PersonNationality values(7,11,3);
insert into PersonNationality values(8,11,2);
insert into PersonNationality values(9,12,5);
insert into PersonNationality values(10,13,5);
insert into PersonNationality values(11,13,8);
insert into PersonNationality values(13,19,8);

#Insert Marriage_Details
insert into MarriageDetails values(111, '1999-09-08', 'India');	
insert into MarriageDetails values(112, '1989-07-03', 'Ukraine');
insert into MarriageDetails values(113, '2000-04-08', 'China');	
insert into MarriageDetails values(114, '1998-09-03', 'Ukraine');
insert into MarriageDetails values(115, '1979-08-08', 'Pakistan');

# Insert Marriage cases
insert into PersonInMarriage values(1, 1, 111, 'Y');
insert into PersonInMarriage values(2, 5, 111, 'Y');
insert into PersonInMarriage values(3, 2, 112, 'Y');
insert into PersonInMarriage values(4, 11, 112, 'Y');
insert into PersonInMarriage values(8, 19, 113, 'Y');
insert into PersonInMarriage values(5, 12, 113, 'Y');
insert into PersonInMarriage values(6, 13, 114, 'Y');
insert into PersonInMarriage values(7, 19, 114, 'Y');

#Insert DeathDetails
insert into DeathDetails values(2, 19, '2008-01-23','accident');
insert into DeathDetails values(1, 1, '2005-01-23','fever');
insert into DeathDetails values(3, 2, '2008-04-3','heartattack');

# Insert DivorceDetails
insert into DivorceDetails values(1, 112, '2014-09-8', 'India');
insert into DivorceDetails values(1, 112, '2014-09-8', 'Ukraine');

select * from PersonInMarriage;

# Delete people from PersonInMarriage when only 1 marriageCertificateNum is present
delete from PersonInMarriage
where marriageCertificateNum in (
select marriageCertificateNum from (select * from PersonInMarriage) as mcn
group by marriageCertificateNum
having count(*) != 2
);

# EXAMPLES:
# 1. POLYGAMY MARRIAGE EXAMPLE
# Inserting people to PersonDetails table whose religion allows multiple marriage
INSERT INTO PersonDetails VALUES(13, 5, 'X', 'T', 'M', 30);
INSERT INTO PersonDetails VALUES(14, 5, 'S', 'H', 'F', 25);
INSERT INTO PersonDetails VALUES(15, 5, 'T', 'B', 'F', 30);

# Inserting Nationality of people into PersonNationality
INSERT INTO PersonNationality VALUES(14, 13, 10);
INSERT INTO PersonNationality VALUES(15, 14, 10);
INSERT INTO PersonNationality VALUES(16, 15, 10);

# Marrying person 13-14 and 13-15 and entering for certificate in MarriageDetails table
INSERT INTO MarriageDetails VALUES(107, '2006-10-12', 'Scotland');
INSERT INTO MarriageDetails VALUES(108, '2016-01-24', 'Scotland');

# Associating these marriage with persons involved in PersonInMarriage table
INSERT INTO PersonInMarriage VALUES(1013, 13, 107, "Y");
INSERT INTO PersonInMarriage VALUES(1014, 14, 107, "Y");

# For second marriage between 13-15
INSERT INTO PersonInMarriage VALUES(1015, 13, 108, "Y");
INSERT INTO PersonInMarriage VALUES(1016, 15, 108, "Y");

# 2. SAME SEX MARRIAGE EXAMPLE
# Inserting people to PersonDetails table with same sex
INSERT INTO PersonDetails VALUES(16, 3, 'Marry', 'Brown', 'F', 30);
INSERT INTO PersonDetails VALUES(17, 3, 'Leona', 'Hurley', 'F', 28);
# Inserting Nationality
INSERT INTO PersonNationality VALUES(17, 16, 1);
INSERT INTO PersonNationality VALUES(18, 17, 1);
# Marriage Certificate generation
INSERT INTO MarriageDetails VALUES(109, '2016-01-24', 'Ireland');
# Person's details in PersonInMarriage
INSERT INTO PersonInMarriage VALUES(1017, 16, 109, "Y");
INSERT INTO PersonInMarriage VALUES(1018, 17, 109, "Y");

# 3. DIVORCED PERSON MARRYING EXAMPLE
# Inserting people to PersonDetails table with same sex
INSERT INTO PersonDetails VALUES(18, 1, 'Mark', 'Bush', 'M', 30);
INSERT INTO PersonDetails VALUES(29, 1, 'Michille', 'Anderson', 'F', 28);
# Inserting Nationality
INSERT INTO PersonNationality VALUES(19, 18, 2);
INSERT INTO PersonNationality VALUES(20, 29, 2);
# Marriage Certificate generation
INSERT INTO MarriageDetails VALUES(110, '2016-01-24', 'India');
# Person's details in PersonInMarriage
INSERT INTO PersonInMarriage VALUES(1019, 18, 110, "Y");
INSERT INTO PersonInMarriage VALUES(1020, 29, 110, "Y");
# Divorcing between them
# | Divorce_Certificate_Number | MarriageCertificateNumber | Divorce_Date | Divorce_Country |
INSERT INTO DivorceDetails VALUES(2001, 110, "2016-06-06", "India");
# Marrying them again with new certificate of marriage
# Marriage Certificate generation
INSERT INTO MarriageDetails VALUES(211, '2016-12-24', 'India');
# Person's details in PersonInMarriage
INSERT INTO PersonInMarriage VALUES(1021, 18, 211, "Y");
INSERT INTO PersonInMarriage VALUES(1022, 29, 211, "Y");

# 4. WIDOW PERSON MARRIAGE EXAMPLE
# Inserting people to PersonDetails table with same sex
INSERT INTO PersonDetails VALUES(30, 1, 'Mark', 'Bush', 'M', 30);
INSERT INTO PersonDetails VALUES(31, 1, 'Michille', 'Anderson', 'F', 28);
# Inserting Nationality
INSERT INTO PersonNationality VALUES(21, 30, 2);
INSERT INTO PersonNationality VALUES(22, 31, 2);
# Marriage Certificate generation
INSERT INTO MarriageDetails VALUES(112, '2016-01-24', 'India');
# Person's details in PersonInMarriage
INSERT INTO PersonInMarriage VALUES(1023, 30, 112, "Y");
INSERT INTO PersonInMarriage VALUES(1024, 31, 112, "Y");
# Entering one partner to dead list
INSERT INTO DeathDetails VALUES(3000, 31, "2016-05-23", "Accident");
#Marrying partner with new certificate
# Marriage Certificate generation
INSERT INTO MarriageDetails VALUES(156, '2016-12-24', 'India');
# Person's details in PersonInMarriage
INSERT INTO PersonInMarriage VALUES(1025, 30, 156, "Y");

# 5. A PERSON CAN HAVE MULTIPLE NATIONALITIES
INSERT INTO PersonDetails VALUES(22, 1, 'Jameson', 'Guiness', 'F', 25);
# Inserting multiple nationalities
INSERT INTO PersonNationality VALUES(23, 22, 1);
INSERT INTO PersonNationality VALUES(24, 22, 2);

# 6. POLYGAMY IS NOT POSSIBLE FOR A PERSON IF RELIGION DOESN'T ALLOW
# Inserting people to PersonDetails table with same sex
INSERT INTO PersonDetails VALUES(50, 1, 'Mark', 'Black', 'M', 30);
# Inserting Nationality
INSERT INTO PersonNationality VALUES(26, 50, 2);
# Marriage Certificate generation
INSERT INTO MarriageDetails VALUES(237, '2016-01-24', 'India');
INSERT INTO PersonInMarriage VALUES(2224, 50, 237, "Y");
# Marrying again
INSERT INTO MarriageDetails VALUES(1105, '2016-01-24', 'India');
# Person's details in PersonInMarriage
INSERT INTO PersonInMarriage VALUES(1025, 50, 1105, "Y");

# 7. CANNOT MARRY TO OUTSIDE PERSON'S NATIONALITY COUNTRY
INSERT INTO PersonDetails VALUES(44, 1, 'Jameson', 'Guiness', 'F', 25);
INSERT INTO PersonNationality VALUES(64, 44, 1);
INSERT INTO MarriageDetails VALUES(214, '2016-01-24', 'India');
INSERT INTO PersonInMarriage VALUES(7234, 44, 214, "Y");

# 8. CHILD MARRIAGE IS NOT POSSIBLE
INSERT INTO PersonDetails VALUES(23, 1, 'TOMMY', 'HANKS', 'M', 12);

# 9. SELF MARRIAGE IS NOT POSSIBLE
-- Inserting people to PersonDetails table with same sex
INSERT INTO PersonDetails VALUES(24, 1, 'Mark', 'Bush', 'M', 30);
-- Inserting Nationality
INSERT INTO PersonNationality VALUES(25, 24, 2);
-- Marriage Certificate generation
INSERT INTO MarriageDetails VALUES(117, '2016-01-24', 'India');
-- Person's details in PersonInMarriage
INSERT INTO PersonInMarriage VALUES(1028, 24, 117, "Y");
INSERT INTO PersonInMarriage VALUES(1029, 24, 117, "Y");

# 10. Marring dead person
-- Inserting people to PersonDetails table with same sex
INSERT INTO PersonDetails VALUES(25, 1, 'Mark', 'Bush', 'M', 30);
INSERT INTO PersonDetails VALUES(26, 1, 'Mary', 'Land', 'F', 29);
-- Inserting Nationality
INSERT INTO PersonNationality VALUES(26, 25, 2);
INSERT INTO PersonNationality VALUES(27, 26, 2);
INSERT INTO MarriageDetails VALUES(122, '2016-01-24', 'India');
INSERT INTO PersonInMarriage VALUES(2913, 25, 122, "Y");
INSERT INTO PersonInMarriage VALUES(2914, 26, 122, "Y");
# Entering one partner to dead list
INSERT INTO DeathDetails VALUES(3000, 26, "2016-05-23", "Accident");
-- Marriage Certificate generation
INSERT INTO MarriageDetails VALUES(118, '2016-01-24', 'India');
-- Person's details in PersonInMarriage
INSERT INTO PersonInMarriage VALUES(1028, 25, 118, "Y");
INSERT INTO PersonInMarriage VALUES(1029, 26, 118, "Y");


# Married People with their relationship status
create view marriedPeople as 
select a.marriageCertificateNum, a.status, a.personID as PersonID1, 
b.personID as PersonID2 from PersonInMarriage a inner join PersonInMarriage b on 
(a.marriageCertificateNum = b.marriageCertificateNum and a.personID > b.personID); 

select * from marriedPeople;


# Married People with their relationship status
create view currentMarriedPeople as 
select a.marriageCertificateNum, a.status, a.personID as PersonID1, 
b.personID as PersonID2 from PersonInMarriage a inner join PersonInMarriage b on 
(a.marriageCertificateNum = b.marriageCertificateNum and a.personID > b.personID)
where a.status = 'Y'; 

select * from CurrentMarriedPeople;


# Divorced Marriages with people
create view divorcedPeople as
select a.marriageCertificateNum, a.personID as Divorcee1, 
b.personID as Divorcee2 from PersonInMarriage a inner join PersonInMarriage b on 
(a.marriageCertificateNum = b.marriageCertificateNum and a.personID > b.personID) 
where a.marriageCertificateNum IN (select marriageCertificateNum from DivorceDetails);        

select * from divorcedPeople;

# People who are widow and are eligible for marriage
create view widowPeopleEligibleForMarriage as 
select a.marriageCertificateNum, b.personID as widow 
from PersonInMarriage a inner join PersonInMarriage b on 
(a.marriageCertificateNum = b.marriageCertificateNum and a.personID != b.personID)
where a.personId IN (select personId from DeathDetails) and
b.status = 'N' and 
b.personId NOT IN (select personId from DeathDetails) and
(select count(status) from PersonInMarriage where PersonInMarriage.personId = b.personId and PersonInMarriage.status = "Y")
<
(select allowedNumOfMarriages from Religion where religionId =
(select religionId from PersonDetails where personId = b.personId));         

select * from widowPeopleEligibleForMarriage;

# People allowed for polygamy according to their religion

create view polygamyAllowed as
select personID , firstName, lastName from PersonDetails p where
(select allowedNumOfMarriages from Religion where religionId = p.religionId)>1;

select * from polygamyAllowed;

# People who married more than once due to any reason

create view MarriedMoreThanOnce as
select personID from PersonInMarriage a where
(select count(marriageCertificateNum) 
from PersonInMarriage where personId = a.personId)>1;

select distinct * from MarriedMoreThanOnce;



