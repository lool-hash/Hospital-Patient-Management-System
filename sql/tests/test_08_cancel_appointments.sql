-- TASK 8 - Cancel all appointments transaction test
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
