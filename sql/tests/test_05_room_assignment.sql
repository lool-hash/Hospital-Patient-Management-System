-- TASK 5 - Room assignment trigger test
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
