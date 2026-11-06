import { BadRequestException } from '@nestjs/common';
import { ListingMediaType } from '@prisma/client';

export interface ListingMediaInput {
  mediaType?: ListingMediaType | string;
  mediaKeys?: string[];
  videoKey?: string | null;
}

export interface NormalizedListingMedia {
  mediaType: ListingMediaType;
  mediaKeys: string[];
  videoKey: string | null;
}

/** Image listings use mediaKeys (max 5); video listings use videoKey — never both. */
export function normalizeListingMedia(
  data: ListingMediaInput,
  options?: { maxImages?: number },
): NormalizedListingMedia {
  const maxImages = options?.maxImages ?? 5;
  const rawType = (data.mediaType ?? ListingMediaType.IMAGE).toString().toUpperCase();
  const mediaType =
    rawType === ListingMediaType.VIDEO ? ListingMediaType.VIDEO : ListingMediaType.IMAGE;
  const videoKey = data.videoKey?.trim() || null;
  const mediaKeys = (data.mediaKeys ?? []).map((k) => k.trim()).filter(Boolean);

  if (mediaType === ListingMediaType.VIDEO) {
    if (!videoKey) {
      throw new BadRequestException('A video file is required for video listings');
    }
    if (mediaKeys.length > 0) {
      throw new BadRequestException('Video listings cannot include images');
    }
    return { mediaType: ListingMediaType.VIDEO, mediaKeys: [], videoKey };
  }

  if (videoKey) {
    throw new BadRequestException('Image listings cannot include a video');
  }
  if (mediaKeys.length > maxImages) {
    throw new BadRequestException(`Maximum ${maxImages} images allowed`);
  }
  return { mediaType: ListingMediaType.IMAGE, mediaKeys, videoKey: null };
}
