const fs = require('fs');
const path = require('path');

function saveToLocal(fileOrBuffer, filePath) {
  let buffer;

  if (Buffer.isBuffer(fileOrBuffer)) {
    buffer = fileOrBuffer;
  } else if (fileOrBuffer?.buffer && Buffer.isBuffer(fileOrBuffer.buffer)) {
    buffer = fileOrBuffer.buffer;
  } else if (fileOrBuffer?.buffer) {
    buffer = Buffer.from(fileOrBuffer.buffer);
  } else {
    buffer = Buffer.from(fileOrBuffer);
  }

  // ✅ Check if filePath already includes a filename (has extension)
  const hasExtension = path.extname(filePath).length > 0;

  let relativePath;
  if (hasExtension) {
    // filePath is a full path including filename — use it directly
    relativePath = filePath;
  } else {
    // filePath is a folder — generate filename as before
    const ext = fileOrBuffer.originalname
      ? fileOrBuffer.originalname.split('.').pop()
      : 'bin';
    const filename = `${Date.now()}-${Math.random().toString(36).substring(7)}.${ext}`;
    relativePath = `${filePath}/${filename}`;
  }

  const fullPath = path.join(__dirname, '..', 'storage', 'uploads', relativePath);

  fs.mkdirSync(path.dirname(fullPath), { recursive: true });
  fs.writeFileSync(fullPath, buffer);

  return `${process.env.SERVER_URL}/storage/uploads/${relativePath}`;
}

module.exports = { saveToLocal };