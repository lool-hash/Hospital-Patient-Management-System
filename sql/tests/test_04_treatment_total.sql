-- TASK 4 - Treatment total calculation test
SET SERVEROUTPUT ON;

DECLARE
  v_total NUMBER;
BEGIN
  v_total := User1.calc_treatment_total(1);
  DBMS_OUTPUT.PUT_LINE('Total Bill = ' || v_total);
END;
/

SELECT total_bill
FROM User1.Patients
WHERE id = 1;
