import { PaymentStatus } from '@prisma/client';

export interface PaymentVerificationResult {
  isSuccess: boolean;
  transactionId: string;
  status: PaymentStatus;
  amountPaid: number;
  rawGatewayResponse: any;
  errorMessage?: string;
}

export class PaymentService {
  private getGatewayError(gateway: string, description: string): PaymentVerificationResult {
    return {
      isSuccess: false,
      transactionId: `UNCONFIGURED-${gateway}-${Date.now()}`,
      status: 'FAILED',
      amountPaid: 0,
      rawGatewayResponse: { gateway, configured: false },
      errorMessage: `${description} Set the required environment variables before enabling ${gateway}.`,
    };
  }

  async verifyKhaltiPayment(token: string, amountInPaisa: number): Promise<PaymentVerificationResult> {
    const khaltiSecret = process.env.KHALTI_SECRET_KEY?.trim();
    const verifyUrl = process.env.KHALTI_VERIFY_URL?.trim();

    if (!khaltiSecret || !verifyUrl) {
      return this.getGatewayError('KHALTI', 'Khalti payment is not configured.');
    }

    try {
      const response = await fetch(verifyUrl, {
        method: 'POST',
        headers: {
          Authorization: `Key ${khaltiSecret}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ token, amount: amountInPaisa }),
      });

      const data = await response.json();
      if (response.ok && data.state?.name === 'Completed') {
        return {
          isSuccess: true,
          transactionId: data.idx ?? `KHALTI-${Date.now()}`,
          status: 'COMPLETED',
          amountPaid: Number((data.amount ?? amountInPaisa) / 100),
          rawGatewayResponse: data,
        };
      }

      return {
        isSuccess: false,
        transactionId: token,
        status: 'FAILED',
        amountPaid: 0,
        rawGatewayResponse: data,
        errorMessage: data.detail || data.message || 'Khalti verification failed',
      };
    } catch (err: any) {
      return {
        isSuccess: false,
        transactionId: token,
        status: 'FAILED',
        amountPaid: 0,
        rawGatewayResponse: null,
        errorMessage: err?.message || 'Khalti verification request failed',
      };
    }
  }

  async verifyEsewaPayment(amt: number, rid: string, pid: string): Promise<PaymentVerificationResult> {
    const merchantCode = process.env.ESEWA_MERCHANT_CODE?.trim();
    const verifyUrl = process.env.ESEWA_VERIFY_URL?.trim();

    if (!merchantCode || !verifyUrl) {
      return this.getGatewayError('ESEWA', 'eSewa payment is not configured.');
    }

    try {
      const params = new URLSearchParams({
        amt: String(amt),
        rid,
        pid,
        scd: merchantCode,
      });

      const response = await fetch(`${verifyUrl}?${params.toString()}`);
      const text = await response.text();
      const payload = { raw: text };

      if (text.includes('Success') || text.includes('response_code>Success')) {
        return {
          isSuccess: true,
          transactionId: rid,
          status: 'COMPLETED',
          amountPaid: amt,
          rawGatewayResponse: payload,
        };
      }

      return {
        isSuccess: false,
        transactionId: rid,
        status: 'FAILED',
        amountPaid: 0,
        rawGatewayResponse: payload,
        errorMessage: 'eSewa transaction was not verified successfully',
      };
    } catch (err: any) {
      return {
        isSuccess: false,
        transactionId: rid,
        status: 'FAILED',
        amountPaid: 0,
        rawGatewayResponse: null,
        errorMessage: err?.message || 'eSewa verification request failed',
      };
    }
  }

  setupCashOnDelivery(orderTotal: number): PaymentVerificationResult {
    return {
      isSuccess: true,
      transactionId: `COD-${Date.now()}`,
      status: 'PENDING',
      amountPaid: orderTotal,
      rawGatewayResponse: { method: 'COD', collectOnDelivery: true },
    };
  }
}
