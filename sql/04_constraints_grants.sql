-- Foreign Key
ALTER TABLE User1.Patients
ADD CONSTRAINT fk_patient_room
FOREIGN KEY (room_id)
REFERENCES User1.Rooms(id);

-- Permissions
GRANT INSERT, SELECT, UPDATE ON User1.Patients TO User2;
GRANT INSERT, SELECT, UPDATE ON User1.Rooms TO User2;
GRANT INSERT, SELECT ON User1.Doctors TO User2;
GRANT INSERT ON User1.AuditTrail TO User2;
