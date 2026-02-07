-- TASK 6 - Discharge patient procedure test
BEGIN
  User1.discharge_patient(1);
END;
/

SELECT status, discharge_date
FROM User1.Patients
WHERE id = 1;
