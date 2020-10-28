SELECT encounter_type_id into @HIV_adult_intake from encounter_type where uuid = 'c31d306a-40c4-11e7-a919-92ebcb67fe33';
SELECT encounter_type_id into @HIV_adult_followup from encounter_type where uuid = 'c31d3312-40c4-11e7-a919-92ebcb67fe33';
SELECT encounter_type_id into @HIV_ped_intake from encounter_type where uuid = 'c31d3416-40c4-11e7-a919-92ebcb67fe33';
SELECT encounter_type_id into @HIV_ped_followup from encounter_type where uuid = 'c31d34f2-40c4-11e7-a919-92ebcb67fe33';
set @present = concept_from_mapping('PIH','11563');
set @absent = concept_from_mapping('PIH','11564');

drop temporary table if exists temp_TB_screening;
create temporary table temp_TB_screening
(
patient_id int(11),
encounter_id int(11),
cough_result varchar(3),
fever_result varchar(3),
weight_loss_result varchar(3),
tb_contact_result varchar(3),
lymph_pain_result varchar(3),
tb_screening_result varchar(3),
tb_screening_date datetime,
index_ascending int(11),
index_descending int(11)
);

-- load temp table with all intake/followup forms with any TB screening answer given
insert into temp_TB_screening (patient_id, encounter_id,tb_screening_date)
select e.patient_id, e.encounter_id,e.encounter_datetime from encounter e
where e.voided =0 
and e.encounter_type in (@HIV_adult_intake,@HIV_adult_followup,@HIV_ped_intake,@HIV_ped_followup)
and exists
  (select 1 from obs o where o.encounter_id = e.encounter_id 
   and o.voided = 0 and o.concept_id in (@absent,@present))
;  

-- update answer of each of the screening questions by bringing in the symptom/answer (fever, weight loss etc...)
-- and update the temp table column based on whether the obs question was symptom question was present or absent
update temp_TB_screening t
inner join obs o on t.encounter_id = o.encounter_id and o.value_coded = concept_from_mapping('PIH', '11565')
set fever_result = if(o.concept_id = @present,'yes',if(o.concept_id = @absent,'no',null))
;

update temp_TB_screening t
inner join obs o on t.encounter_id = o.encounter_id and o.value_coded = concept_from_mapping('PIH', '11566')
set weight_loss_result = if(o.concept_id = @present,'yes',if(o.concept_id = @absent,'no',null))
;

update temp_TB_screening t
inner join obs o on t.encounter_id = o.encounter_id and o.value_coded = concept_from_mapping('PIH', '11567')
set cough_result = if(o.concept_id = @present,'yes',if(o.concept_id = @absent,'no',null))
;

update temp_TB_screening t
inner join obs o on t.encounter_id = o.encounter_id and o.value_coded = concept_from_mapping('PIH', '11568')
set tb_contact_result = if(o.concept_id = @present,'yes',if(o.concept_id = @absent,'no',null))
;

update temp_TB_screening t
inner join obs o on t.encounter_id = o.encounter_id and o.value_coded = concept_from_mapping('PIH', '11569')
set lymph_pain_result = if(o.concept_id = @present,'yes',if(o.concept_id = @absent,'no',null))
;

-- if any of the screening questions are yes, screening result = yes
update temp_TB_screening t
set tb_screening_result = if(cough_result = 'yes','yes',if(fever_result='yes','yes',if(tb_contact_result='yes','yes',if(lymph_pain_result='yes','yes',if(weight_loss_result='yes','yes', 'no')))));

-- The ascending/descending indexes are calculated ordering on the screening date
-- new temp tables are used to build them and then joined into the main temp table. 
-- index ascending
drop temporary table if exists temp_screening_index_asc;
CREATE TEMPORARY TABLE temp_screening_index_asc
(
    SELECT
            patient_id,
            encounter_id,
            tb_screening_date,
            index_asc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_asc,
            patient_id,
            encounter_id,
            tb_screening_date,
            @u:= patient_id
      FROM temp_TB_screening,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id ASC, tb_screening_date ASC, encounter_id ASC
        ) index_ascending);

update temp_TB_screening t
inner join temp_screening_index_asc tsia on tsia.encounter_id = t.encounter_id
set t.index_ascending = tsia.index_asc;


-- index descending
drop temporary table if exists temp_screening_index_desc;
CREATE TEMPORARY TABLE temp_screening_index_desc
(
    SELECT
            patient_id,
            encounter_id,
            tb_screening_date,
            index_DESC
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_DESC,
            patient_id,
            encounter_id,
            tb_screening_date,
            @u:= patient_id
      FROM temp_TB_screening,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id DESC, tb_screening_date DESC, encounter_id DESC
        ) index_DESCending);

update temp_TB_screening t
inner join temp_screening_index_desc tsid on tsid.encounter_id = t.encounter_id
set t.index_descending = tsid.index_desc;

-- select results
select * from temp_TB_screening
ORDER BY patient_id ASC, tb_screening_date ASC, encounter_id ASC;
