// Source inventory for billing translations. Handles Dart interpolation and
// adjacent string literals without evaluating or changing business expressions.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
function strings(source) {
  const found = [];
  function literal(start) {
    const raw = source[start] === 'r';
    let i = start + (raw ? 1 : 0);
    const quote = source[i];
    const delimiter = source.slice(i, i + 3) === quote.repeat(3) ? quote.repeat(3) : quote;
    i += delimiter.length;
    let text = '', count = 0;
    while (i < source.length) {
      if (source.startsWith(delimiter, i)) return {start, end: i + delimiter.length, text};
      if (!raw && source[i] === '\\') {
        const next = source[++i];
        text += ({n:'\n',r:'\r',t:'\t'})[next] ?? next; i++; continue;
      }
      if (!raw && source[i] === '$') {
        if (source[i + 1] === '{') {
          i += 2; let depth = 1;
          while (i < source.length && depth) {
            if (source[i] === "'" || source[i] === '"') { i = literal(i).end; continue; }
            if (source[i] === '{') depth++;
            if (source[i] === '}') depth--;
            i++;
          }
          text += `{${count++}}`; continue;
        }
        const match = source.slice(i + 1).match(/^[A-Za-z_]\w*/);
        if (match) { text += `{${count++}}`; i += match[0].length + 1; continue; }
      }
      text += source[i++];
    }
    return {start, end:i, text};
  }
  for (let i = 0; i < source.length;) {
    if (source.startsWith('//', i)) { i = source.indexOf('\n', i); if (i < 0) break; continue; }
    if (source.startsWith('/*', i)) { const end = source.indexOf('*/', i + 2); i = end < 0 ? source.length : end + 2; continue; }
    if (source[i] === "'" || source[i] === '"' || (source[i] === 'r' && /['"]/.test(source[i + 1] ?? ''))) {
      const value = literal(i);
      const previous = found.at(-1);
      if (previous && /^\s*$/.test(source.slice(previous.end, i))) {
        const offset = [...previous.text.matchAll(/\{\d+\}/g)].length;
        previous.text += value.text.replace(/\{(\d+)\}/g, (_,n) => `{${Number(n)+offset}}`);
        previous.end = value.end;
      } else found.push(value);
      i = value.end;
    } else i++;
  }
  return found;
}
const admin = path.join(root, 'lib/screens/admin');
const extra = ['lib/theme/admin_widgets.dart', 'lib/widgets/static_fonepay_payment_dialog.dart',
  'lib/widgets/offline_customer_dialog.dart','lib/widgets/local_billing_status_panel.dart',
  'lib/widgets/fonepay_payment_dialog.dart','lib/widgets/store_animation.dart',
  'lib/widgets/stock_summary_panel.dart','lib/models/stock_summary.dart',
  'lib/screens/billing/billing_shell.dart','lib/widgets/readable_product_card.dart',
  'lib/screens/auth/login_screen.dart','lib/screens/auth/forgot_password_screen.dart',
  'lib/screens/auth/email_verification_screen.dart','lib/screens/auth/register_screen.dart',
  'lib/widgets/custom_button.dart'];
const files = [...fs.readdirSync(admin).filter(p=>p.endsWith('.dart')).map(p=>'lib/screens/admin/'+p), ...extra];
const inventory = new Set();
for (const file of files) for (const value of strings(fs.readFileSync(path.join(root,file),'utf8'))) {
  if (/[A-Za-z]{2}/.test(value.text) && !value.text.includes('package:') &&
      !/^(\.\.?\/|https?:|assets\/)/.test(value.text) &&
      (/\s/.test(value.text) || /^[A-Z][a-z]+$/.test(value.text) || /^[A-Z][A-Z _&]+$/.test(value.text)) && value.text.length < 900) inventory.add(value.text);
}
const catalog=JSON.parse(fs.readFileSync(path.join(root,'assets/translations/billing_ne.json'),'utf8'));
const missing=[...inventory].sort().filter(key=>!catalog[key]);
console.log(`${files.length} billing files; ${inventory.size} translation candidates.`);
console.log(`${missing.length} candidates not yet translated.`);
if(missing.length) { console.log(missing.join('\n')); process.exitCode=1; }
module.exports = {strings, files};
