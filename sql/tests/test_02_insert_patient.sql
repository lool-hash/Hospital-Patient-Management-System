-- TASK 2 - Insert patient test
INSERT INTO User1.Patients (name, status)
VALUES ('Test Patient 1', 'Admitted');

COMMIT;

SELECT id, status, room_id, admission_date
FROM User1.Patients
WHERE name = 'Test Patient 1';
