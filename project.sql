DROP TRIGGER SYS.TRG_LOG_USER_CREATION;

BEGIN
  FOR u IN (SELECT username FROM dba_users 
            WHERE username IN ('MANAGERUSER','USER1','USER2')) LOOP
    EXECUTE IMMEDIATE 'DROP USER '||u.username||' CASCADE';
  END LOOP;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 
  'DROP TABLESPACE HOSPITAL_TBS INCLUDING CONTENTS AND DATAFILES';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
-- TASK 1 – DATABASE SETUP & USER MANAGEMENT

-- CREATE TABLESPACE
===============================
CREATE TABLESPACE HOSPITAL_TBS
DATAFILE 'hospital_data.dbf' SIZE 100M
AUTOEXTEND ON NEXT 10M;

-- USER MANAGEMENT
===============================

CREATE USER ManagerUser IDENTIFIED BY Manager123
DEFAULT TABLESPACE HOSPITAL_TBS
QUOTA UNLIMITED ON HOSPITAL_TBS;

GRANT CONNECT, RESOURCE, DBA, CREATE USER TO ManagerUser;

-- user 1& 2

CREATE USER User1 IDENTIFIED BY User123
DEFAULT TABLESPACE HOSPITAL_TBS
QUOTA UNLIMITED ON HOSPITAL_TBS;

CREATE USER User2 IDENTIFIED BY User123
DEFAULT TABLESPACE HOSPITAL_TBS
QUOTA UNLIMITED ON HOSPITAL_TBS;

GRANT CONNECT, RESOURCE, CREATE TABLE, CREATE SEQUENCE,
      CREATE TRIGGER, CREATE PROCEDURE TO User1;

GRANT CONNECT TO User2;

-- SEQUENCES
===============================
CREATE SEQUENCE User1.seq_patients;
CREATE SEQUENCE User1.seq_rooms;
CREATE SEQUENCE User1.seq_doctors;
CREATE SEQUENCE User1.seq_audit;

-- TABLES
===============================
CREATE TABLE User1.Rooms (
  id NUMBER PRIMARY KEY,
  type VARCHAR2(20),
  capacity NUMBER,
  availability VARCHAR2(20)
);

CREATE TABLE User1.Patients (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(100),
  date_of_birth DATE,
  status VARCHAR2(20),
  total_bill NUMBER DEFAULT 0,
  room_id NUMBER,
  admission_date DATE,
  discharge_date DATE
);

CREATE TABLE User1.Doctors (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(100),
  specialty VARCHAR2(50),
  available_hours NUMBER
);

CREATE TABLE User1.AuditTrail (
  id NUMBER PRIMARY KEY,
  table_name VARCHAR2(50),
  operation VARCHAR2(30),
  old_data VARCHAR2(4000),
  new_data VARCHAR2(4000),
  log_date DATE DEFAULT SYSDATE,
  performed_by VARCHAR2(50) DEFAULT USER
);

-- Foreign Key
ALTER TABLE User1.Patients
ADD CONSTRAINT fk_patient_room
FOREIGN KEY (room_id) REFERENCES User1.Rooms(id);

-- PERMISSIONS FOR USER2
===============================
GRANT INSERT, SELECT, UPDATE ON User1.Patients TO User2;
GRANT INSERT, SELECT, UPDATE ON User1.Rooms TO User2;
GRANT INSERT, SELECT ON User1.Doctors TO User2;
GRANT INSERT ON User1.AuditTrail TO User2;

-- DDL TRIGGER – USER CREATION LOG
===============================
CREATE OR REPLACE TRIGGER trg_log_user_creation
AFTER CREATE ON DATABASE
DECLARE
  v_sql ORA_NAME_LIST_T;
  v_cnt NUMBER;
  v_stmt VARCHAR2(4000);
BEGIN
  v_cnt := ORA_SQL_TXT(v_sql);
  FOR i IN 1..v_cnt LOOP
    v_stmt := v_stmt || v_sql(i);
  END LOOP;

  IF UPPER(v_stmt) LIKE '%CREATE USER%' THEN
    INSERT INTO User1.AuditTrail
    VALUES (
      User1.seq_audit.NEXTVAL,
      'DATABASE',
      'USER_CREATED',
      NULL,
      SUBSTR(v_stmt,1,3900),
      SYSDATE,
      USER
    );
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- SAMPLE DATA
===============================
INSERT INTO User1.Rooms VALUES (User1.seq_rooms.NEXTVAL,'ICU',1,'Available');
INSERT INTO User1.Rooms VALUES (User1.seq_rooms.NEXTVAL,'General',4,'Available');
INSERT INTO User1.Rooms VALUES (User1.seq_rooms.NEXTVAL,'Private',1,'Available');
INSERT INTO User1.Rooms VALUES (User1.seq_rooms.NEXTVAL,'Emergency',2,'Available');
INSERT INTO User1.Rooms VALUES (User1.seq_rooms.NEXTVAL,'General',4,'Available');

INSERT INTO User1.Doctors VALUES (User1.seq_doctors.NEXTVAL,'Dr Sarah','Cardiology',40);
INSERT INTO User1.Doctors VALUES (User1.seq_doctors.NEXTVAL,'Dr Mike','Neurology',35);
INSERT INTO User1.Doctors VALUES (User1.seq_doctors.NEXTVAL,'Dr Emily','Pediatrics',40);
INSERT INTO User1.Doctors VALUES (User1.seq_doctors.NEXTVAL,'Dr James','Ortho',30);
INSERT INTO User1.Doctors VALUES (User1.seq_doctors.NEXTVAL,'Dr Lisa','Emergency',45);

COMMIT;
-- Test case --
SELECT
  (SELECT COUNT(*) FROM dba_users 
   WHERE username IN ('MANAGERUSER','USER1','USER2')) AS users_created,
  (SELECT COUNT(*) FROM dba_tablespaces 
   WHERE tablespace_name = 'HOSPITAL_TBS') AS tbs_created
FROM dual;


-- TASK 2 – ADMISSION VALIDATION
===============================
CREATE OR REPLACE TRIGGER User1.trg_patient_admission
BEFORE INSERT ON User1.Patients
FOR EACH ROW
DECLARE
  v_room_id NUMBER;
BEGIN
  IF :NEW.id IS NULL THEN
    SELECT User1.seq_patients.NEXTVAL INTO :NEW.id FROM dual;
  END IF;

  IF :NEW.status = 'Admitted' THEN
    SELECT id INTO v_room_id
    FROM User1.Rooms
    WHERE availability = 'Available'
    AND ROWNUM = 1;

    :NEW.room_id := v_room_id;
    :NEW.admission_date := SYSDATE;

    UPDATE User1.Rooms
    SET availability = 'Occupied'
    WHERE id = v_room_id;

    INSERT INTO User1.AuditTrail
    VALUES (
      User1.seq_audit.NEXTVAL,
      'Patients',
      'INSERT',
      NULL,
      'Patient admitted to room '||v_room_id,
      SYSDATE,
      USER
    );
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20001,'No available rooms');
END;
/

CREATE TABLE User1.Appointments (
  id               NUMBER PRIMARY KEY,
  patient_id       NUMBER NOT NULL,
  doctor_id        NUMBER NOT NULL,
  appointment_date DATE   NOT NULL,
  status           VARCHAR2(20) DEFAULT 'Scheduled' NOT NULL
);

ALTER TABLE User1.Appointments
  ADD CONSTRAINT fk_app_patient
  FOREIGN KEY (patient_id) REFERENCES User1.Patients(id);

ALTER TABLE User1.Appointments
  ADD CONSTRAINT fk_app_doctor
  FOREIGN KEY (doctor_id) REFERENCES User1.Doctors(id);

CREATE SEQUENCE User1.seq_appointments START WITH 1 INCREMENT BY 1;
--test case --
INSERT INTO User1.Patients (name, status)
VALUES ('Test Patient 1', 'Admitted');

COMMIT;

SELECT id, status, room_id, admission_date
FROM User1.Patients
WHERE name = 'Test Patient 1';


-- TASK 3 – APPOINTMENT SCHEDULING

CREATE OR REPLACE PROCEDURE User1.schedule_appointment (
  p_patient_id IN NUMBER,
  p_doctor_id  IN NUMBER,
  p_date       IN DATE
)
IS
  v_hours NUMBER;
BEGIN

  SELECT available_hours
  INTO v_hours
  FROM User1.Doctors
  WHERE id = p_doctor_id
  FOR UPDATE;

  IF v_hours <= 0 THEN
    RAISE_APPLICATION_ERROR(-20010, 'Doctor is not available (no available hours).');
  END IF;

  INSERT INTO User1.Appointments (id, patient_id, doctor_id, appointment_date, status)
  VALUES (User1.seq_appointments.NEXTVAL, p_patient_id, p_doctor_id, p_date, 'Scheduled');

  UPDATE User1.Doctors
  SET available_hours = available_hours - 1
  WHERE id = p_doctor_id;

  INSERT INTO User1.AuditTrail (id, table_name, operation, old_data, new_data, log_date, performed_by)
  VALUES (
    User1.seq_audit.NEXTVAL,
    'Appointments',
    'INSERT',
    NULL,
    'Scheduled appointment: patient_id='||p_patient_id||', doctor_id='||p_doctor_id||
    ', date='||TO_CHAR(p_date,'YYYY-MM-DD HH24:MI'),
    SYSDATE,
    USER
  );

  COMMIT;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20011, 'Doctor not found.');
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/
SHOW ERRORS;


BEGIN
  User1.schedule_appointment(p_patient_id => 1, p_doctor_id => 1, p_date => SYSDATE + (2/24));
END;
/
SELECT * FROM User1.Appointments ORDER BY id;
SELECT id, name, available_hours FROM User1.Doctors ORDER BY id;

CREATE TABLE User1.Treatments (
  id NUMBER PRIMARY KEY,
  patient_id NUMBER NOT NULL,
  doctor_id NUMBER NOT NULL,
  description VARCHAR2(200),
  cost NUMBER NOT NULL
);

CREATE OR REPLACE TRIGGER User1.trg_treatments_id
BEFORE INSERT ON User1.Treatments
FOR EACH ROW
BEGIN
  IF :NEW.id IS NULL THEN
    SELECT NVL(MAX(id),0) + 1
    INTO :NEW.id
    FROM User1.Treatments;
  END IF;
END;
/
--test case --
BEGIN
  User1.schedule_appointment(1, 1, SYSDATE + 1);
END;
/

SELECT a.id, a.status, d.available_hours
FROM User1.Appointments a
JOIN User1.Doctors d ON a.doctor_id = d.id
WHERE a.patient_id = 1;

-- TASK 4 – TREATMENT COST CALCULATION

CREATE OR REPLACE FUNCTION User1.calc_treatment_total (
  p_patient_id IN NUMBER
)
RETURN NUMBER
IS
  v_total NUMBER;
BEGIN
  SELECT NVL(SUM(cost), 0)
  INTO v_total
  FROM User1.Treatments
  WHERE patient_id = p_patient_id;

  UPDATE User1.Patients
  SET total_bill = v_total
  WHERE id = p_patient_id;

  RETURN v_total;
END;
/
--test case--
-- TEST CASE TASK 4 

DECLARE
  v_total NUMBER;
BEGIN
  v_total := User1.calc_treatment_total(1);
  DBMS_OUTPUT.PUT_LINE('Total Bill = ' || v_total);
END;
/

SELECT total_bill
FROM User1.Patients
WHERE id = 1;

-- TASK 5 – ROOM ASSIGNMENT TRACKING

CREATE OR REPLACE TRIGGER User1.trg_assign_room
BEFORE INSERT ON User1.Patients
FOR EACH ROW
DECLARE

  v_room_id  NUMBER;
  v_capacity NUMBER;
  v_audit_id NUMBER;
BEGIN
  IF :NEW.room_id IS NULL THEN

 
    SELECT id, capacity
    INTO v_room_id, v_capacity
    FROM (
      SELECT id, capacity
      FROM User1.Rooms
      WHERE availability = 'Available'
        AND capacity > 0
      ORDER BY capacity DESC, id
    )
    WHERE ROWNUM = 1;

    :NEW.room_id := v_room_id;

    BEGIN
      IF :NEW.admission_date IS NULL THEN
        :NEW.admission_date := SYSDATE;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NULL; 
    END;

    UPDATE User1.Rooms
    SET capacity = capacity - 1,
        availability =
          CASE
            WHEN capacity - 1 <= 0 THEN 'Unavailable'
            ELSE availability
          END
    WHERE id = v_room_id;

    SELECT NVL(MAX(id), 0) + 1
    INTO v_audit_id
    FROM User1.AuditTrail;

    INSERT INTO User1.AuditTrail
      (id, table_name, operation, old_data, new_data)
    VALUES
      (v_audit_id,
       'Patients',
       'INSERT',
       NULL,
       'Assigned room_id=' || v_room_id || ' to patient_id=' || :NEW.id);

  END IF;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20030, 'No available rooms for admission.');
END;
/
SHOW ERRORS;
---test case --
INSERT INTO User1.Patients (name, status)
VALUES ('Room Test Patient', 'Admitted');

COMMIT;

SELECT id, name, room_id, admission_date
FROM User1.Patients
WHERE name = 'Room Test Patient';

SELECT id, capacity, availability
FROM User1.Rooms
WHERE id = (
  SELECT room_id
  FROM User1.Patients
  WHERE name = 'Room Test Patient'
);


-- TASK 6 – DISCHARGE PROCESSING

CREATE OR REPLACE PROCEDURE User1.discharge_patient (
  p_patient_id IN NUMBER
)
IS
  v_room_id User1.Patients.room_id%TYPE;
BEGIN

  SELECT room_id
  INTO v_room_id
  FROM User1.Patients
  WHERE id = p_patient_id
  FOR UPDATE;


  UPDATE User1.Patients
  SET status = 'Discharged',
      discharge_date = SYSDATE
  WHERE id = p_patient_id;


  UPDATE User1.Rooms
  SET capacity = capacity + 1,
      availability = 'Available'
  WHERE id = v_room_id;


  INSERT INTO User1.AuditTrail
  VALUES (
    User1.seq_audit.NEXTVAL,
    'Patients',
    'DISCHARGE',
    'Patient ID = ' || p_patient_id,
    'Room ID = ' || v_room_id || ' released',
    SYSDATE,
    USER
  );

  COMMIT;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20040, 'Patient not found or not admitted.');
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/
SHOW ERRORS;
-- test case--
BEGIN
  User1.discharge_patient(1);
END;
/

SELECT status, discharge_date
FROM User1.Patients
WHERE id = 1;

-- task 7 --

DECLARE
  v_total_admissions  NUMBER;
  v_total_discharges  NUMBER;
  v_avg_stay          NUMBER;

  CURSOR c_top_doctors IS
    SELECT d.name, COUNT(t.id) AS treatment_count
    FROM User1.Doctors d
    JOIN User1.Treatments t ON d.id = t.doctor_id
    GROUP BY d.name
    ORDER BY treatment_count DESC
    FETCH FIRST 3 ROWS ONLY;

BEGIN
  -- Total admissions
  SELECT COUNT(*)
  INTO v_total_admissions
  FROM User1.Patients
  WHERE status = 'Admitted';

  -- Total discharges
  SELECT COUNT(*)
  INTO v_total_discharges
  FROM User1.Patients
  WHERE status = 'Discharged';

  -- Average stay duration
  SELECT AVG(discharge_date - admission_date)
  INTO v_avg_stay
  FROM User1.Patients
  WHERE discharge_date IS NOT NULL;

  DBMS_OUTPUT.PUT_LINE('--- Hospital Performance Report ---');
  DBMS_OUTPUT.PUT_LINE('Total Admissions : ' || v_total_admissions);
  DBMS_OUTPUT.PUT_LINE('Total Discharges : ' || v_total_discharges);
  DBMS_OUTPUT.PUT_LINE('Average Stay (days): ' || NVL(v_avg_stay, 0));

  DBMS_OUTPUT.PUT_LINE('Top 3 Doctors by Treatments:');
  FOR r IN c_top_doctors LOOP
    DBMS_OUTPUT.PUT_LINE('- ' || r.name || ' : ' || r.treatment_count);
  END LOOP;
END;
/
-- test case --
SET SERVEROUTPUT ON
DECLARE
  v_dummy NUMBER;
BEGIN
  -- تشغيل التقرير بالكامل
  NULL;
END;
/

-- TASK 8 --

DECLARE
  v_failed EXCEPTION;
BEGIN
  FOR r IN (
    SELECT id
    FROM User1.Appointments
    WHERE status = 'Scheduled'
  ) LOOP

    UPDATE User1.Appointments
    SET status = 'Cancelled'
    WHERE id = r.id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE v_failed;
    END IF;

  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('All appointments cancelled successfully.');

EXCEPTION
  WHEN v_failed THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Cancellation failed. All changes rolled back.');
END;
/
--test case --
BEGIN
  FOR r IN (SELECT id FROM User1.Appointments) LOOP
    UPDATE User1.Appointments
    SET status = 'Cancelled'
    WHERE id = r.id;
  END LOOP;
  COMMIT;
END;
/

SELECT COUNT(*) AS cancelled_count
FROM User1.Appointments
WHERE status = 'Cancelled';


-- TASK 9 – PATIENT WARNINGS AND STATUS UPDATE
CREATE TABLE User1.Patient_Warnings (
  id          NUMBER PRIMARY KEY,
  patient_id  NUMBER NOT NULL,
  reason      VARCHAR2(200),
  warning_date DATE DEFAULT SYSDATE
);
CREATE SEQUENCE User1.seq_warnings;
CREATE OR REPLACE PROCEDURE User1.issue_patient_warning (
  p_patient_id IN NUMBER,
  p_reason     IN VARCHAR2
)
IS
  v_warning_count NUMBER;
BEGIN
  -- إدخال تحذير جديد
  INSERT INTO User1.Patient_Warnings
  VALUES (
    User1.seq_warnings.NEXTVAL,
    p_patient_id,
    p_reason,
    SYSDATE
  );

  -- حساب عدد التحذيرات
  SELECT COUNT(*)
  INTO v_warning_count
  FROM User1.Patient_Warnings
  WHERE patient_id = p_patient_id;

  -- تحديث حالة المريض إذا وصل 3 تحذيرات
  IF v_warning_count >= 3 THEN
    UPDATE User1.Patients
    SET status = 'Flagged'
    WHERE id = p_patient_id;

    INSERT INTO User1.AuditTrail
    VALUES (
      User1.seq_audit.NEXTVAL,
      'Patients',
      'STATUS UPDATE',
      'Status before update',
      'Patient flagged due to 3 warnings',
      SYSDATE,
      USER
    );
  END IF;

  -- تسجيل التحذير في AuditTrail
  INSERT INTO User1.AuditTrail
  VALUES (
    User1.seq_audit.NEXTVAL,
    'Patient_Warnings',
    'INSERT',
    NULL,
    'Warning issued to patient_id=' || p_patient_id ||
    ' | Reason: ' || p_reason,
    SYSDATE,
    USER
  );

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/
SHOW ERRORS;

SELECT id, status FROM User1.Patients WHERE id = 1;
SELECT * FROM User1.Patient_Warnings WHERE patient_id = 1;
SELECT * FROM User1.AuditTrail ORDER BY id DESC;
--tset case--
BEGIN
  User1.issue_patient_warning(1,'Warning 1');
  User1.issue_patient_warning(1,'Warning 2');
  User1.issue_patient_warning(1,'Warning 3');
END;
/

SELECT status
FROM User1.Patients
WHERE id = 1;


-- TASK 10 --

CREATE OR REPLACE FUNCTION get_doctor_patient_count (
  p_doctor_id IN NUMBER
)
RETURN NUMBER
IS
  v_count NUMBER;
BEGIN
  SELECT COUNT(DISTINCT patient_id)
  INTO v_count
  FROM User1.Treatments
  WHERE doctor_id = p_doctor_id;

  RETURN v_count;
END;
/
CREATE OR REPLACE PROCEDURE update_patient_status_by_bill (
  p_threshold IN NUMBER
)
IS
BEGIN
  FOR r IN (
    SELECT id
    FROM User1.Patients
    WHERE total_bill > p_threshold
  ) LOOP

    UPDATE User1.Patients
    SET status = 'High-Value'
    WHERE id = r.id;

    INSERT INTO User1.AuditTrail
      (id, table_name, operation, old_data, new_data)
    VALUES
      (User1.seq_audit.NEXTVAL,
       'Patients',
       'UPDATE',
       NULL,
       'Status updated to High-Value for patient_id=' || r.id);

  END LOOP;

  COMMIT;
END;
/
--test case--
BEGIN
  update_patient_status_by_bill(500);
END;
/

SELECT id, status
FROM User1.Patients
WHERE total_bill > 500;

-- task 12 --
-- show blocking info --

SELECT
  s.sid,
  s.serial#,
  s.username,
  s.status,
  s.blocking_session
FROM v$session s
WHERE s.username IN ('USER1','USER2');

SELECT
  s1.username AS waiting_user,
  s1.sid AS waiting_sid,
  s2.username AS blocking_user,
  s2.sid AS blocking_sid
FROM v$session s1
JOIN v$session s2
ON s1.blocking_session = s2.sid;

commit ;

--test case--

SELECT
  s.username,
  s.sid,
  s.blocking_session
FROM v$session s
WHERE s.username IN ('USER1','USER2');
