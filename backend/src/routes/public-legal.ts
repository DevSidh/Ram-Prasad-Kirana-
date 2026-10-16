import { Router, type NextFunction, type Request, type Response } from 'express';
import path from 'node:path';

const publicDirectory = path.resolve(__dirname, '../../public');

function sendPublicFile(fileName: string) {
  return (_req: Request, res: Response, next: NextFunction) => {
    res.sendFile(path.join(publicDirectory, fileName), (error) => {
      if (error) next(error);
    });
  };
}

export function createPublicLegalRouter(): Router {
  const router = Router();
  router.get('/privacy-policy', sendPublicFile('privacy-policy.html'));
  router.get('/account-deletion', sendPublicFile('account-deletion.html'));
  router.get('/legal.css', sendPublicFile('legal.css'));
  return router;
}
