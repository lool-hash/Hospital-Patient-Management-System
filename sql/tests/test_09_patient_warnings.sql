-- TASK 9 - Issue patient warnings test
BEGIN
  User1.issue_patient_warning(1,'Warning 1');
  User1.issue_patient_warning(1,'Warning 2');
  User1.issue_patient_warning(1,'Warning 3');
END;
/

SELECT status
FROM User1.Patients
WHERE id = 1;
