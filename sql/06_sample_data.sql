INSERT INTO User1.Rooms
VALUES (User1.seq_rooms.NEXTVAL,'ICU',1,'Available');

INSERT INTO User1.Rooms
VALUES (User1.seq_rooms.NEXTVAL,'General',4,'Available');

INSERT INTO User1.Rooms
VALUES (User1.seq_rooms.NEXTVAL,'Private',1,'Available');

INSERT INTO User1.Rooms
VALUES (User1.seq_rooms.NEXTVAL,'Emergency',2,'Available');

INSERT INTO User1.Doctors
VALUES (User1.seq_doctors.NEXTVAL,'Dr Sarah','Cardiology',40);

INSERT INTO User1.Doctors
VALUES (User1.seq_doctors.NEXTVAL,'Dr Mike','Neurology',35);

INSERT INTO User1.Doctors
VALUES (User1.seq_doctors.NEXTVAL,'Dr Emily','Pediatrics',40);

INSERT INTO User1.Doctors
VALUES (User1.seq_doctors.NEXTVAL,'Dr James','Ortho',30);

INSERT INTO User1.Doctors
VALUES (User1.seq_doctors.NEXTVAL,'Dr Lisa','Emergency',45);

COMMIT;
