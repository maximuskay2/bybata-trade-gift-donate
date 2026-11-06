const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

function normalizeBase(input) {
  const cleaned = (input || '')
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, '');
  if (cleaned.length >= 3) return cleaned;
  if (cleaned.length > 0) return `user${cleaned}`;
  return 'user';
}

function uniqueName(base, existing) {
  if (!existing.has(base)) return base;
  let i = 1;
  while (true) {
    const suffix = `${i}`;
    const maxBase = Math.max(1, 20 - suffix.length);
    const candidate = `${base.slice(0, maxBase)}${suffix}`;
    if (!existing.has(candidate)) return candidate;
    i += 1;
  }
}

async function main() {
  const existing = new Set(
    (await prisma.profile.findMany({
      where: { username: { not: null } },
      select: { username: true },
    }))
      .map((p) => p.username)
      .filter(Boolean)
      .map((u) => u.toLowerCase()),
  );

  const profiles = await prisma.profile.findMany({
    where: { username: null },
    select: {
      id: true,
      displayName: true,
      user: { select: { email: true } },
    },
  });

  let updated = 0;
  for (const profile of profiles) {
    const emailPrefix = (profile.user?.email || '').split('@')[0];
    const base = normalizeBase(profile.displayName || emailPrefix);
    const username = uniqueName(base, existing);
    await prisma.profile.update({
      where: { id: profile.id },
      data: { username },
    });
    existing.add(username);
    updated += 1;
  }

  console.log(`✅ Backfilled usernames for ${updated} profiles.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
