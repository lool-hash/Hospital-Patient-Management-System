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
