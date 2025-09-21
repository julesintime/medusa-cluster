const fs = require("fs");
const path = require("path");

async function generateApiKeys() {
  try {
    console.log("Setting up frontend environment configuration...");
    
    // For now, we'll create a basic configuration
    // The Medusa v2 doesn't require publishable keys for basic storefront operation
    const envContent = `NEXT_PUBLIC_MEDUSA_BACKEND_URL=${process.env.MEDUSA_BACKEND_URL || "http://medusa:9000"}
MEDUSA_BACKEND_URL=${process.env.MEDUSA_BACKEND_URL || "http://medusa:9000"}
`;

    // Create shared directory if it doesn't exist
    if (!fs.existsSync("/shared")) {
      fs.mkdirSync("/shared", { recursive: true });
    }

    fs.writeFileSync("/shared/frontend.env", envContent);
    console.log("Frontend environment saved to /shared/frontend.env");
    console.log("Backend URL configured:", process.env.MEDUSA_BACKEND_URL || "http://medusa:9000");

  } catch (error) {
    console.error("Error setting up frontend environment:", error);
    // Create minimal config even on error
    try {
      if (!fs.existsSync("/shared")) {
        fs.mkdirSync("/shared", { recursive: true });
      }
      const fallbackEnv = `NEXT_PUBLIC_MEDUSA_BACKEND_URL=http://medusa:9000
MEDUSA_BACKEND_URL=http://medusa:9000
`;
      fs.writeFileSync("/shared/frontend.env", fallbackEnv);
    } catch (e) {
      console.error("Failed to write fallback config:", e);
    }
  }
}

generateApiKeys();