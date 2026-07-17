#!/usr/bin/env node

import { createHash } from 'node:crypto'
import { createReadStream } from 'node:fs'
import { rename, stat, unlink, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const MANIFEST_PATH = resolve(REPO_ROOT, 'manifest.json')
const CIRCUIT_TYPES = ['deposit', 'withdraw', 'refund']
const TIERS = [8, 16, 32, 64, 128]

async function sha256(filePath) {
  const hash = createHash('sha256')
  await new Promise((resolveHash, rejectHash) => {
    const stream = createReadStream(filePath)
    stream.on('data', chunk => hash.update(chunk))
    stream.on('end', resolveHash)
    stream.on('error', rejectHash)
  })
  return hash.digest('hex')
}

async function describeArtifact(key, relativePath) {
  const filePath = resolve(REPO_ROOT, relativePath)
  let fileStat
  try {
    fileStat = await stat(filePath)
  } catch {
    throw new Error(`Missing artifact: ${relativePath}`)
  }
  if (!fileStat.isFile()) throw new Error(`Artifact is not a file: ${relativePath}`)

  return {
    key,
    relativePath,
    size: fileStat.size,
    sha256: await sha256(filePath),
  }
}

async function main() {
  const descriptions = []
  for (const type of CIRCUIT_TYPES) {
    for (const tier of TIERS) {
      const circuit = `${type}_${tier}`
      descriptions.push(
        await describeArtifact(`${circuit}.wasm`, `${circuit}_js/${circuit}.wasm`),
        await describeArtifact(`${circuit}.zkey`, `${circuit}_final.zkey`),
      )
    }
  }

  descriptions.sort((a, b) => a.key.localeCompare(b.key))
  const bundleHash = createHash('sha256')
  for (const artifact of descriptions) {
    bundleHash.update(`${artifact.key}\0${artifact.relativePath}\0${artifact.size}\0${artifact.sha256}\n`)
  }

  const artifacts = Object.fromEntries(descriptions.map(artifact => [
    artifact.key,
    {
      path: artifact.relativePath,
      size: artifact.size,
      sha256: artifact.sha256,
    },
  ]))
  const manifest = {
    schemaVersion: 1,
    bundleVersion: bundleHash.digest('hex'),
    generatedAt: new Date().toISOString(),
    artifacts,
  }

  const tempPath = `${MANIFEST_PATH}.tmp-${process.pid}`
  try {
    await writeFile(tempPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8')
    await rename(tempPath, MANIFEST_PATH)
  } catch (error) {
    await unlink(tempPath).catch(() => {})
    throw error
  }

  console.log(`Generated manifest.json for ${descriptions.length} artifacts`)
  console.log(`Bundle version: ${manifest.bundleVersion}`)
}

main().catch(error => {
  console.error(`Failed to generate manifest: ${error instanceof Error ? error.message : String(error)}`)
  process.exitCode = 1
})
