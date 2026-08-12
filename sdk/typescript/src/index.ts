/**
 * TypeScript SDK for the pryx harness API.
 *
 * ```ts
 * import { PryxClient } from "@1jehuang/pryx-sdk";
 * const client = await PryxClient.connect({ clientName: "my-app/1.0" });
 * const session = await client.createSession(process.cwd());
 * const turn = await client.run(session.session_id, "hello");
 * console.log(turn.text);
 * client.close();
 * ```
 */

export * from "./protocol.js";
export * from "./sockets.js";
export * from "./framing.js";
export { HarnessError } from "./errors.js";
export {
  launchInstance,
  inheritCredentials,
  userPryxHome,
  userAppConfigDir,
} from "./launch.js";
export type { LaunchOptions, LaunchedInstance } from "./launch.js";
export { bundledPryxBinary, platformBinaryPackage } from "./binary.js";
export { PryxClient, unixSocketTransport } from "./client.js";
export type {
  ConnectOptions,
  FileContent,
  FileStatus,
  GlobalEventsOptions,
  RunOptions,
  RunStructuredOptions,
  RuntimeInfo,
  SendMessageOptions,
  StructuredTurnResult,
  Transport,
  TurnResult,
} from "./client.js";
export { StructuredOutputError } from "./structured.js";
export type {
  StructuredOutputAttempt,
  StructuredOutputSchema,
  StructuredValidationIssue,
} from "./structured.js";
