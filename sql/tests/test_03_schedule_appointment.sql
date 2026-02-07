-- TASK 3 - Schedule appointment test
BEGIN
  User1.schedule_appointment(1, 1, SYSDATE + 1);
END;
/

SELECT a.id, a.status, d.available_hours
FROM User1.Appointments a
JOIN User1.Doctors d ON a.doctor_id = d.id
WHERE a.patient_id = 1;
