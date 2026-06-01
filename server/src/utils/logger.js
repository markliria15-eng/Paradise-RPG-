function now() {
  return new Date().toISOString();
}

function info(message, meta = null) {
  if (meta) {
    console.log(`[${now()}] INFO ${message}`, meta);
    return;
  }
  console.log(`[${now()}] INFO ${message}`);
}

function warn(message, meta = null) {
  if (meta) {
    console.warn(`[${now()}] WARN ${message}`, meta);
    return;
  }
  console.warn(`[${now()}] WARN ${message}`);
}

function error(message, meta = null) {
  if (meta) {
    console.error(`[${now()}] ERROR ${message}`, meta);
    return;
  }
  console.error(`[${now()}] ERROR ${message}`);
}

module.exports = { info, warn, error };

