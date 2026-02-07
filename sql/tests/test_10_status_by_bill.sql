-- TASK 10 - Update patient status based on bill test
BEGIN
  update_patient_status_by_bill(500);
END;
/

SELECT id, status
FROM User1.Patients
WHERE total_bill > 500;
