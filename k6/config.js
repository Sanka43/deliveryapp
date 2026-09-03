// Shared config for every k6 script. Override via `-e NAME=value` on the
// k6 CLI. Defaults point at the local Firebase emulator.
export const PROJECT_ID = __ENV.PROJECT_ID || 'mnd-masterndelivery';
export const REGION = __ENV.REGION || 'asia-south1';

// Emulator callable/HTTP URL shape: http://localhost:5001/<project>/<region>/<functionName>
// Override BASE_URL to point at a deployed environment instead.
export const BASE_URL =
  __ENV.BASE_URL || `http://localhost:5001/${PROJECT_ID}/${REGION}`;
