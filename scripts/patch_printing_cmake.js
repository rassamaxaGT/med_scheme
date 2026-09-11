const fs = require('fs');
const path = require('path');

const targetPath = path.join(
  process.env.LOCALAPPDATA,
  'Pub',
  'Cache',
  'hosted',
  'pub.dev',
  'printing-5.14.3',
  'windows',
  'CMakeLists.txt'
);

if (!fs.existsSync(targetPath)) {
  console.log('Printing CMakeLists.txt not found at:', targetPath);
  process.exit(0);
}

let content = fs.readFileSync(targetPath, 'utf8');

const targetBlock = `include(../windows/DownloadProject.cmake)
download_project(PROJ
                 pdfium
                 URL
                 \${PDFIUM_URL})`;

const replacementBlock = `if(EXISTS "\${CMAKE_BINARY_DIR}/pdfium-src/PDFiumConfig.cmake")
  set(pdfium_SOURCE_DIR "\${CMAKE_BINARY_DIR}/pdfium-src")
else()
  include(../windows/DownloadProject.cmake)
  download_project(PROJ
                   pdfium
                   URL
                   \${PDFIUM_URL}
                   URL_HASH SHA256=8E900C3E5103AE9A3AA7800653E804575C687D132FCFB4DEDA7BB2CE04ACA8D2)
endif()`;

if (!content.includes('URL_HASH SHA256')) {
  content = content.replace(targetBlock, replacementBlock);
  fs.writeFileSync(targetPath, content, 'utf8');
  console.log('Successfully patched printing CMakeLists.txt with URL_HASH and pre-extracted check!');
} else {
  console.log('Already patched with URL_HASH.');
}
