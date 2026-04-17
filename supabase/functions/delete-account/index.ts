import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response("Unauthorized", { status: 401 });
    }

    const userJwt = authHeader.replace("Bearer ", "");

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Verify the user's JWT and get their ID
    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await userClient.auth.getUser(userJwt);
    if (userError || !user) {
      return new Response("Unauthorized", { status: 401 });
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // Delete the user's auth account; RLS/cascades handle table rows
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);
    if (deleteError) {
      return new Response(`Delete failed: ${deleteError.message}`, { status: 500 });
    }

    return new Response(JSON.stringify({ deleted: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(String(err), { status: 500 });
  }
});
