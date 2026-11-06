type VerificationDocumentRow = {
  type: string;
  status: string;
  fileName: string;
  documentKey: string;
  uploadedAt: Date;
};

export function mapKycStatusToClient(status?: string | null): string {
  switch ((status ?? 'NOT_VERIFIED').toUpperCase()) {
    case 'VERIFIED':
      return 'verified';
    case 'PENDING':
      return 'pending';
    case 'REJECTED':
      return 'rejected';
    default:
      return 'unverified';
  }
}

export function buildVerificationState(
  user: { emailVerifiedAt?: Date | null },
  profile: {
    kycStatus?: string | null;
    kycNote?: string | null;
    phoneVerifiedAt?: Date | null;
    phone?: string | null;
  },
  documents: VerificationDocumentRow[],
) {
  const completed = new Set<string>();
  if (user.emailVerifiedAt) completed.add('email');
  if (profile.phoneVerifiedAt) completed.add('phone');
  for (const doc of documents) {
    if (doc.type) completed.add(doc.type);
  }

  return {
    status: mapKycStatusToClient(profile.kycStatus),
    completedVerifications: Array.from(completed),
    rejectionReason: profile.kycNote ?? undefined,
    emailVerified: !!user.emailVerifiedAt,
    phoneVerified: !!profile.phoneVerifiedAt,
    verifiedAt:
      profile.kycStatus === 'VERIFIED' ? new Date().toISOString() : undefined,
    documents: documents.map((d) => ({
      type: d.type,
      status: d.status,
      fileName: d.fileName,
      documentKey: d.documentKey,
      uploadedAt: d.uploadedAt.toISOString(),
    })),
  };
}
