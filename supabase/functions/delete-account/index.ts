import { createClient } from "https://esm.sh/@supabase/supabase-js@2.52.0";

const buckets = ["catch-photos", "tackle-photos", "avatars"];
const pageSize = 1000;

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return response({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    return response({ error: "Authentication is required." }, 401);
  }

  const supabaseURL = requiredEnvironment("SUPABASE_URL");
  const publishableKey = requiredEnvironment("SUPABASE_ANON_KEY");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const userClient = createClient(supabaseURL, publishableKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return response({ error: "Authentication is required." }, 401);
  }

  const admin = createClient(supabaseURL, serviceRoleKey);
  try {
    for (const bucket of buckets) {
      const paths = await objectPaths(admin, bucket, userData.user.id);
      for (let index = 0; index < paths.length; index += 100) {
        const { error } = await admin.storage.from(bucket).remove(paths.slice(index, index + 100));
        if (error) throw error;
      }
    }
    const { error } = await admin.auth.admin.deleteUser(userData.user.id);
    if (error) throw error;
    return response({ deleted: true }, 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Account deletion failed.";
    return response({ error: message }, 500);
  }
});

async function objectPaths(client: ReturnType<typeof createClient>, bucket: string, root: string) {
  const paths: string[] = [];
  const directories = [root];
  while (directories.length > 0) {
    const directory = directories.pop()!;
    for (let offset = 0;; offset += pageSize) {
      const { data, error } = await client.storage.from(bucket).list(directory, {
        limit: pageSize,
        offset,
        sortBy: { column: "name", order: "asc" },
      });
      if (error) throw error;
      for (const item of data) {
        const path = `${directory}/${item.name}`;
        if (item.id === null) directories.push(path);
        else paths.push(path);
      }
      if (data.length < pageSize) break;
    }
  }
  return paths;
}

function requiredEnvironment(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}.`);
  return value;
}

function response(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
