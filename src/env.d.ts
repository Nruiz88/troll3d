/// <reference path="../.astro/types.d.ts" />

type SupabaseUser = import('@supabase/supabase-js').User;

declare namespace App {
  interface Locals {
    user: SupabaseUser | null;
    isAdmin: boolean;
  }
}
