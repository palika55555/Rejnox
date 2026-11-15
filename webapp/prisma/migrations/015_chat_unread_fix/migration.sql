-- Rejnox: oprava počítania neprečítaných správ.
-- Konverzácia vzniká v tej istej transakcii ako prvá správa, takže
-- last_read_at = now() sa rovnal času tej správy a nerátala sa ako neprečítaná.
-- Nový člen preto ešte nič neprečítal (-infinity).

ALTER TABLE conversation_members ALTER COLUMN last_read_at SET DEFAULT '-infinity';

UPDATE conversation_members cm SET last_read_at = '-infinity'
WHERE NOT EXISTS (
  SELECT 1 FROM messages m
  WHERE m.conversation_id = cm.conversation_id
    AND m.sender_id = cm.user_id
    AND m.sent_at >= cm.last_read_at
)
AND cm.last_read_at = (SELECT c.created_at FROM conversations c WHERE c.id = cm.conversation_id);
