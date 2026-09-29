// Node demo. Build first:
//
//     moon build examples/web --target js --release
//     node examples/web/demo.mjs
//
// The path below is where `moon` puts the JS build of this package.
import { opencc_to_taiwan, opencc_to_simplified } from "../../_build/js/release/build/examples/web/web.js";

const samples = [
  "内存泄漏与软件优化",
  "较低级别的官员由总统任命。",
  "我们在网络上传输这个档案。",
];

for (const text of samples) {
  const traditional = opencc_to_taiwan(text);
  console.log(`${text}\n  → TW  ${traditional}\n  → 简  ${opencc_to_simplified(traditional)}`);
}
