DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname = 'public'
  LOOP
    EXECUTE FORMAT('ALTER TABLE %I.%I REPLICA IDENTITY FULL;', r.schemaname, r.tablename);
  END LOOP;
END$$;


SELECT slot_name, plugin, slot_type, active, restart_lsn
FROM pg_replication_slots;
