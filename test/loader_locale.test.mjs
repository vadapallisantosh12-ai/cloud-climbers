import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const shell = readFileSync(new URL('../web/loading.html', import.meta.url), 'utf8');
const start = shell.indexOf('let zh = ');
const end = shell.indexOf("retry.addEventListener('click'", start);
assert(start >= 0 && end > start, 'loader locale initialization exists');
const initialization = shell.slice(start, end);
const browserDefault = language => language.toLowerCase().startsWith('zh') ? 'zh-CN' : 'en';
for (const [saved, stored] of [[null, null], ['en', 'en'], ['zh-CN', 'zh-CN'], ['invalid', null]]) {
  test(`loader preference ${saved ?? '(fresh)'} selects ${stored ?? 'the browser language'}`, () => {
    for (const language of ['en-US', 'zh-CN', 'zh-Hant', 'fr-FR']) {
      const expected = stored ?? browserDefault(language);
      const title = {};
      const context = {
        navigator: { language },
        localStorage: { getItem: () => saved },
        document: { documentElement: {}, getElementById: () => title },
        status: {}, retry: {}, progress: { setAttribute() {} },
      };
      vm.runInNewContext(initialization, context);
      assert.equal(context.document.documentElement.lang, expected);
      assert.equal(context.status.textContent, expected === 'en' ? 'Loading…' : '正在加载…');
      assert.equal(context.retry.textContent, expected === 'en' ? 'Retry' : '重试');
      assert.equal(title.textContent, 'Vertical Platformer');
    }
  });
}
test('blocked browser storage leaves the browser-language loader usable', () => {
  const context = {
    navigator: { language: 'en-US', languages: ['en-US', 'zh-CN'] },
    localStorage: { getItem() { throw new Error('blocked'); } },
    document: { documentElement: {}, getElementById: () => ({}) },
    status: {}, retry: {}, progress: { setAttribute() {} },
  };
  vm.runInNewContext(initialization, context);
  assert.equal(context.document.documentElement.lang, 'en');
  assert.equal(context.status.textContent, 'Loading…');
});
