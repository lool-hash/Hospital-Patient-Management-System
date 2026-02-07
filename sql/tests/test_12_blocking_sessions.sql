-- BONUS - Blocking sessions check (requires privileges)
SELECT
  s.username,
  s.sid,
  s.blocking_session
FROM v$session s
WHERE s.username IN ('USER1','USER2');
