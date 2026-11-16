import type { Db, Tx } from "./db";
import { HttpError } from "./errors";

// Komunita – príspevky, lajky a komentáre. Čítať môže každý prihlásený,
// zapisovať a mazať len vlastné (RLS v 019_community).

/** Koľko príspevkov príde naraz. */
export const FEED_PAGE = 30;
const COMMENTS_LIMIT = 100;

export type CommunityPost = {
  id: string;
  authorId: string;
  authorName: string;
  body: string;
  createdAt: Date;
  likes: number;
  comments: number;
  likedByMe: boolean;
  mine: boolean;
};

export type CommunityComment = {
  id: string;
  authorId: string;
  authorName: string;
  body: string;
  createdAt: Date;
  mine: boolean;
};

export const notFound = (what = "Príspevok") => new HttpError(404, "not_found", `${what} sa nenašiel.`);

const POST_COLUMNS = `
  p.id::text, p.author_id::text AS "authorId", coalesce(pp.display_name, 'Používateľ') AS "authorName",
  p.body, p.created_at AS "createdAt",
  (SELECT count(*)::int FROM community_post_likes l WHERE l.post_id = p.id) AS likes,
  (SELECT count(*)::int FROM community_comments c WHERE c.post_id = p.id) AS comments,
  EXISTS (SELECT 1 FROM community_post_likes l WHERE l.post_id = p.id AND l.user_id = $1::uuid) AS "likedByMe",
  p.author_id = $1::uuid AS mine`;

async function postById(tx: Tx, userId: string, postId: string): Promise<CommunityPost> {
  const [post] = await tx.query<CommunityPost>(
    `SELECT ${POST_COLUMNS}
     FROM community_posts p LEFT JOIN public_profiles pp ON pp.id = p.author_id
     WHERE p.id = $2::uuid`,
    [userId, postId],
  );
  if (!post) throw notFound();
  return post;
}

/** Najnovšie príspevky; `before` = čas posledného načítaného (stránkovanie). */
export function feed(db: Db, userId: string, before: Date | null): Promise<CommunityPost[]> {
  return db.asUser(userId, (tx) =>
    tx.query<CommunityPost>(
      `SELECT ${POST_COLUMNS}
       FROM community_posts p LEFT JOIN public_profiles pp ON pp.id = p.author_id
       WHERE $2::timestamptz IS NULL OR p.created_at < $2::timestamptz
       ORDER BY p.created_at DESC, p.id DESC
       LIMIT ${FEED_PAGE}`,
      [userId, before],
    ),
  );
}

export function createPost(db: Db, userId: string, body: string): Promise<CommunityPost> {
  return db.asUser(userId, async (tx) => {
    const [{ id }] = await tx.query<{ id: string }>(
      "INSERT INTO community_posts (author_id, body) VALUES ($1::uuid, $2) RETURNING id::text",
      [userId, body],
    );
    return postById(tx, userId, id);
  });
}

export function deletePost(db: Db, userId: string, postId: string): Promise<void> {
  return db.asUser(userId, async (tx) => {
    const rows = await tx.query("DELETE FROM community_posts WHERE id = $1::uuid AND author_id = $2::uuid RETURNING id", [
      postId,
      userId,
    ]);
    if (rows.length === 0) throw notFound();
  });
}

/** Lajk zapne (`liked`) alebo vypne a vráti príspevok s novými počtami. */
export function setLike(db: Db, userId: string, postId: string, liked: boolean): Promise<CommunityPost> {
  return db.asUser(userId, async (tx) => {
    await postById(tx, userId, postId);
    if (liked) {
      await tx.query(
        "INSERT INTO community_post_likes (post_id, user_id) VALUES ($1::uuid, $2::uuid) ON CONFLICT DO NOTHING",
        [postId, userId],
      );
    } else {
      await tx.query("DELETE FROM community_post_likes WHERE post_id = $1::uuid AND user_id = $2::uuid", [postId, userId]);
    }
    return postById(tx, userId, postId);
  });
}

const COMMENT_COLUMNS = `
  c.id::text, c.author_id::text AS "authorId", coalesce(pp.display_name, 'Používateľ') AS "authorName",
  c.body, c.created_at AS "createdAt", c.author_id = $1::uuid AS mine`;

export function comments(db: Db, userId: string, postId: string): Promise<CommunityComment[]> {
  return db.asUser(userId, async (tx) => {
    await postById(tx, userId, postId);
    return tx.query<CommunityComment>(
      `SELECT ${COMMENT_COLUMNS}
       FROM community_comments c LEFT JOIN public_profiles pp ON pp.id = c.author_id
       WHERE c.post_id = $2::uuid
       ORDER BY c.created_at, c.id
       LIMIT ${COMMENTS_LIMIT}`,
      [userId, postId],
    );
  });
}

export function addComment(db: Db, userId: string, postId: string, body: string): Promise<CommunityComment> {
  return db.asUser(userId, async (tx) => {
    await postById(tx, userId, postId);
    const [{ id }] = await tx.query<{ id: string }>(
      "INSERT INTO community_comments (post_id, author_id, body) VALUES ($1::uuid, $2::uuid, $3) RETURNING id::text",
      [postId, userId, body],
    );
    const [comment] = await tx.query<CommunityComment>(
      `SELECT ${COMMENT_COLUMNS}
       FROM community_comments c LEFT JOIN public_profiles pp ON pp.id = c.author_id
       WHERE c.id = $2::uuid`,
      [userId, id],
    );
    return comment;
  });
}

/** Komentár zmaže jeho autor alebo autor príspevku (pravidlo v RLS). */
export function deleteComment(db: Db, userId: string, commentId: string): Promise<void> {
  return db.asUser(userId, async (tx) => {
    const rows = await tx.query("DELETE FROM community_comments WHERE id = $1::uuid RETURNING id", [commentId]);
    if (rows.length === 0) throw notFound("Komentár");
  });
}
