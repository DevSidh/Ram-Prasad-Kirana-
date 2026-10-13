import { Router, type RequestHandler, type Response } from 'express';
import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { getImageMimeType, receiveSingleImage } from '../services/image-upload.js';
import { isPushConfigured } from '../services/push-notifications.js';
import { identityAlreadyInUse, normalizePhone } from '../services/user-identity.js';

const addressFields = {
  title: z.string().trim().min(1).max(40),
  fullName: z.string().trim().min(1).max(120),
  phone: z.string().trim().min(7).max(30),
  province: z.string().trim().min(1).max(100),
  city: z.string().trim().min(1).max(100),
  street: z.string().trim().min(1).max(240),
  landmark: z.string().trim().max(240).nullable().optional(),
  instructions: z.string().trim().max(500).nullable().optional(),
  isDefault: z.boolean().optional(),
  latitude: z.number().finite().min(-90).max(90).nullable().optional(),
  longitude: z.number().finite().min(-180).max(180).nullable().optional(),
};
const createAddressInput = z.object(addressFields).strict();
const updateAddressInput = z.object(addressFields).partial().strict()
  .refine((value) => Object.keys(value).length > 0);
const updateProfileInput = z.object({
  fullName: z.string().trim().min(1).max(120),
  phone: z.string().trim().min(7).max(30).nullable()
    .transform((phone) => normalizePhone(phone))
    .refine((phone) => phone === null || (phone.length >= 7 && phone.length <= 30)),
}).strict();
const deviceTokenInput = z.object({
  token: z.string().trim().min(20).max(4096),
  platform: z.enum(['android', 'ios', 'web']),
}).strict();

function authenticatedUserId(res: Response): string | null {
  const id = res.locals.authenticatedUserId;
  return typeof id === 'string' ? id : null;
}

function addressResponse(address: {
  id: string;
  label: string | null;
  fullName: string;
  phone: string;
  province: string | null;
  city: string;
  addressLine1: string;
  addressLine2: string | null;
  instructions: string | null;
  isDefault: boolean;
  latitude: number | null;
  longitude: number | null;
}) {
  return {
    id: address.id,
    title: address.label ?? 'Home',
    fullName: address.fullName,
    phone: address.phone,
    province: address.province ?? '',
    city: address.city,
    street: address.addressLine1,
    landmark: address.addressLine2,
    instructions: address.instructions,
    isDefault: address.isDefault,
    latitude: address.latitude,
    longitude: address.longitude,
  };
}

function addressData(input: Partial<z.infer<typeof createAddressInput>>) {
  return {
    ...(input.title !== undefined ? { label: input.title } : {}),
    ...(input.fullName !== undefined ? { fullName: input.fullName } : {}),
    ...(input.phone !== undefined ? { phone: input.phone } : {}),
    ...(input.province !== undefined ? { province: input.province } : {}),
    ...(input.city !== undefined ? { city: input.city } : {}),
    ...(input.street !== undefined ? { addressLine1: input.street } : {}),
    ...(input.landmark !== undefined ? { addressLine2: input.landmark } : {}),
    ...(input.instructions !== undefined ? { instructions: input.instructions } : {}),
    ...(input.isDefault !== undefined ? { isDefault: input.isDefault } : {}),
    ...(input.latitude !== undefined ? { latitude: input.latitude } : {}),
    ...(input.longitude !== undefined ? { longitude: input.longitude } : {}),
  };
}

export function createAccountRouter(
  prisma: PrismaClient,
  authenticateToken: RequestHandler,
): Router {
  const router = Router();
  router.use(authenticateToken);

  router.get('/notifications', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const notifications = await prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 100,
      });
      return res.json({
        data: notifications,
        pushAvailable: isPushConfigured(),
      });
    } catch (error) {
      console.error('Notification list failed:', error);
      return res.status(500).json({ error: 'Unable to load your notifications.' });
    }
  });

  router.patch('/notifications/:id/read', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const updated = await prisma.notification.updateMany({
        where: { id: req.params.id, userId },
        data: { isRead: true },
      });
      if (updated.count !== 1) {
        return res.status(404).json({ error: 'Notification not found.' });
      }
      return res.sendStatus(204);
    } catch (error) {
      console.error('Notification read update failed:', error);
      return res.status(500).json({ error: 'Unable to update this notification.' });
    }
  });

  router.delete('/notifications', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      await prisma.notification.deleteMany({ where: { userId } });
      return res.sendStatus(204);
    } catch (error) {
      console.error('Notification clear-all failed:', error);
      return res.status(500).json({ error: 'Unable to delete your notifications.' });
    }
  });

  router.delete('/notifications/:id', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const deleted = await prisma.notification.deleteMany({
        where: { id: req.params.id, userId },
      });
      if (deleted.count !== 1) {
        return res.status(404).json({ error: 'Notification not found.' });
      }
      return res.sendStatus(204);
    } catch (error) {
      console.error('Notification deletion failed:', error);
      return res.status(500).json({ error: 'Unable to delete this notification.' });
    }
  });

  router.post('/notifications/device-token', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = deviceTokenInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'A valid push token and platform are required.' });
    }
    try {
      await prisma.deviceToken.upsert({
        where: { token: parsed.data.token },
        create: {
          userId,
          token: parsed.data.token,
          platform: parsed.data.platform,
        },
        update: { userId, platform: parsed.data.platform },
      });
      return res.status(200).json({ pushAvailable: isPushConfigured() });
    } catch (error) {
      console.error('Push token registration failed:', error);
      return res.status(500).json({ error: 'Unable to enable push notifications.' });
    }
  });

  router.delete('/notifications/device-token/:token', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      await prisma.deviceToken.deleteMany({
        where: { userId, token: req.params.token },
      });
      return res.sendStatus(204);
    } catch (error) {
      console.error('Push token removal failed:', error);
      return res.status(500).json({ error: 'Unable to disable push notifications.' });
    }
  });

  router.patch('/profile', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = updateProfileInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter a valid name and phone number.' });
    }
    try {
      const currentUser = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true },
      });
      if (!currentUser) return res.status(404).json({ error: 'Account not found.' });
      if (await identityAlreadyInUse(prisma, {
        phone: parsed.data.phone,
        excludeUserId: userId,
      })) {
        return res.status(409).json({ error: 'That phone number is already in use.' });
      }
      const user = await prisma.user.update({
        where: { id: userId },
        data: parsed.data,
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          role: true,
          avatarUrl: true,
        },
      });
      return res.json({
        data: {
          id: user.id,
          fullName: user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
          avatarUrl: user.avatarUrl,
        },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === 'P2002') {
        return res.status(409).json({ error: 'That phone number is already in use.' });
      }
      console.error('Profile update failed:', error);
      return res.status(500).json({ error: 'Unable to update your profile.' });
    }
  });

  router.get('/profile/avatar/:userId', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    if (req.params.userId !== userId) {
      return res.status(403).json({ error: 'You cannot view this profile photo.' });
    }

    try {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { avatarData: true, avatarMimeType: true },
      });
      if (!user?.avatarData || !user.avatarMimeType) {
        return res.status(404).json({ error: 'Profile photo not found.' });
      }
      res.setHeader('Content-Type', user.avatarMimeType);
      res.setHeader('Cache-Control', 'private, max-age=86400');
      return res.send(Buffer.from(user.avatarData));
    } catch (error) {
      console.error('Profile image retrieval failed:', error);
      return res.status(500).json({ error: 'Unable to load your profile photo.' });
    }
  });

  router.post('/profile/avatar', receiveSingleImage, async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    if (!req.file) return res.status(400).json({ error: 'Choose an image to upload.' });

    try {
      const avatarMimeType = getImageMimeType(req.file.buffer);
      if (!avatarMimeType) {
        return res.status(400).json({ error: 'Use a valid JPEG, PNG, or WebP image.' });
      }
      const avatarUrl =
        `/account/profile/avatar/${userId}?v=${Date.now()}`;
      const user = await prisma.user.update({
        where: { id: userId },
        data: {
          avatarUrl,
          avatarData: req.file.buffer,
          avatarMimeType,
        },
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          role: true,
          avatarUrl: true,
        },
      });
      return res.json({
        data: {
          id: user.id,
          fullName: user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
          avatarUrl: user.avatarUrl,
        },
      });
    } catch (error) {
      console.error('Profile image upload failed:', error);
      return res.status(500).json({ error: 'Unable to update your profile photo.' });
    }
  });

  router.get('/addresses', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const addresses = await prisma.address.findMany({
        where: { userId },
        orderBy: [{ isDefault: 'desc' }, { createdAt: 'asc' }],
      });
      return res.json({ data: addresses.map(addressResponse) });
    } catch (error) {
      console.error('Address list failed:', error);
      return res.status(500).json({ error: 'Unable to load delivery addresses.' });
    }
  });

  router.post('/addresses', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = createAddressInput.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Check the delivery address details.' });

    try {
      const created = await prisma.$transaction(async (transaction) => {
        const count = await transaction.address.count({ where: { userId } });
        const shouldDefault = parsed.data.isDefault === true || count === 0;
        if (shouldDefault) await transaction.address.updateMany({ where: { userId }, data: { isDefault: false } });
        return transaction.address.create({
          data: {
            label: parsed.data.title,
            fullName: parsed.data.fullName,
            phone: parsed.data.phone,
            province: parsed.data.province,
            city: parsed.data.city,
            addressLine1: parsed.data.street,
            addressLine2: parsed.data.landmark ?? null,
            instructions: parsed.data.instructions ?? null,
            latitude: parsed.data.latitude ?? null,
            longitude: parsed.data.longitude ?? null,
            userId,
            isDefault: shouldDefault,
          },
        });
      });
      return res.status(201).json({ data: addressResponse(created) });
    } catch (error) {
      console.error('Address creation failed:', error);
      return res.status(500).json({ error: 'Unable to save this delivery address.' });
    }
  });

  router.patch('/addresses/:id', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = updateAddressInput.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Check the delivery address details.' });

    try {
      const updated = await prisma.$transaction(async (transaction) => {
        const existing = await transaction.address.findFirst({
          where: { id: req.params.id, userId },
        });
        if (!existing) return null;
        if (parsed.data.isDefault === true) {
          await transaction.address.updateMany({ where: { userId }, data: { isDefault: false } });
        }
        const result = await transaction.address.updateMany({
          where: { id: existing.id, userId },
          data: addressData(parsed.data),
        });
        if (result.count !== 1) return null;
        return transaction.address.findUnique({ where: { id: existing.id } });
      });
      if (!updated) return res.status(404).json({ error: 'Delivery address not found.' });
      return res.json({ data: addressResponse(updated) });
    } catch (error) {
      console.error('Address update failed:', error);
      return res.status(500).json({ error: 'Unable to update this delivery address.' });
    }
  });

  router.delete('/addresses/:id', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const wasDefault = await prisma.$transaction(async (transaction) => {
        const existing = await transaction.address.findFirst({
          where: { id: req.params.id, userId },
        });
        if (!existing) return null;
        const deleted = await transaction.address.deleteMany({
          where: { id: existing.id, userId },
        });
        if (deleted.count !== 1) return null;
        if (existing.isDefault) {
          const nextDefault = await transaction.address.findFirst({
            where: { userId },
            orderBy: { createdAt: 'asc' },
          });
          if (nextDefault) {
            await transaction.address.update({
              where: { id: nextDefault.id },
              data: { isDefault: true },
            });
          }
        }
        return true;
      });
      if (wasDefault === null) return res.status(404).json({ error: 'Delivery address not found.' });
      return res.sendStatus(204);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        console.error('Address deletion failed:', error);
        return res.status(500).json({ error: 'Unable to remove this delivery address.' });
      }
      console.error('Address deletion failed:', error);
      return res.status(500).json({ error: 'Unable to remove this delivery address.' });
    }
  });

  return router;
}
