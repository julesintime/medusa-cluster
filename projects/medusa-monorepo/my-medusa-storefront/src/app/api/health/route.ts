import { NextResponse } from 'next/server'

export async function GET() {
  try {
    // Check if the application is healthy
    // You can add more sophisticated health checks here
    return NextResponse.json(
      { 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        service: 'medusa-storefront'
      },
      { status: 200 }
    )
  } catch (error) {
    return NextResponse.json(
      { 
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        service: 'medusa-storefront',
        error: error instanceof Error ? error.message : 'Unknown error'
      },
      { status: 500 }
    )
  }
}