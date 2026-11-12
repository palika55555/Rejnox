import { describe, expect, it } from "vitest";
import { HttpError } from "./errors";
import { readJsonBody } from "./http";

/** Požiadavka s telom ako stream, bez hlavičky content-length. */
function streamed(chunks: string[]): Request {
  const encoder = new TextEncoder();
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      for (const chunk of chunks) controller.enqueue(encoder.encode(chunk));
      controller.close();
    },
  });
  return new Request("http://localhost/api/x", { method: "POST", body, duplex: "half" } as RequestInit);
}

async function status(promise: Promise<unknown>): Promise<string> {
  try {
    await promise;
    return "ok";
  } catch (error) {
    if (error instanceof HttpError) return `${error.status} ${error.code}`;
    throw error;
  }
}

describe("readJsonBody", () => {
  it("načíta JSON objekt", async () => {
    expect(await readJsonBody(streamed(['{"a":', "1}"]))).toEqual({ a: 1 });
  });

  it("príliš veľké telo bez content-length zastaví počas čítania", async () => {
    const chunks = Array.from({ length: 100 }, () => "x".repeat(1024));
    expect(await status(readJsonBody(streamed(chunks), 16 * 1024))).toBe("413 body_too_large");
  });

  it("veľké content-length odmietne hneď", async () => {
    const request = new Request("http://localhost/api/x", {
      method: "POST",
      body: "{}",
      headers: { "content-length": "999999" },
    });
    expect(await status(readJsonBody(request, 1024))).toBe("413 body_too_large");
  });

  it("pole alebo nezmysel nie je platné telo", async () => {
    expect(await status(readJsonBody(streamed(["[1,2]"])))).toBe("400 invalid_json");
    expect(await status(readJsonBody(streamed(["{nie"])))).toBe("400 invalid_json");
  });
});
