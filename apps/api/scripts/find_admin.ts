import { PrismaClient } from '@prisma/client';

async function main() {
  const prisma = new PrismaClient();
  const admin = await prisma.user.findFirst({ where: { role: 'ADMIN' } });
  if (!admin) {
    console.log(JSON.stringify({ found: false }));
    return;
  }
  console.log(JSON.stringify({ found: true, id: admin.id, email: admin.email }));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});