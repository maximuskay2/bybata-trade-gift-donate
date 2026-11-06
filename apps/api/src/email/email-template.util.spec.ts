import {
  customSchemeToHttpsUrl,
  processSimpleConditionals,
  renderEmailHtml,
} from './email-template.util';

describe('email-template.util', () => {
  it('converts bybata:// links to https universal links', () => {
    expect(customSchemeToHttpsUrl('bybata://trade/abc')).toBe(
      'https://bybata.com/open-app?path=%2Ftrade%2Fabc',
    );
  });

  it('processes {{#if}} blocks', () => {
    const html = '{{#if show}}<a href="{{url}}">Go</a>{{/if}}';
    expect(
      processSimpleConditionals(html, { show: true, url: 'https://bybata.com/open-app' }),
    ).toContain('<a href="{{url}}">');
    expect(processSimpleConditionals(html, { show: false, url: 'x' })).toBe('');
  });

  it('normalizes custom scheme and adds button link attributes', () => {
    const raw = `<html><head><style></style></head><body>
      <a href="bybata://campaign/1" class="btn-3d">View</a>
    </body></html>`;
    const out = renderEmailHtml(raw, {});
    expect(out).toContain('href="https://bybata.com/open-app?path=%2Fcampaign%2F1"');
    expect(out).toContain('target="_blank"');
    expect(out).toContain('pointer-events: auto');
  });

  it('replaces unreplaced template tokens in href with open-app fallback', () => {
    const raw = '<a href="{{missingUrl}}" class="btn-3d">Broken</a>';
    const out = renderEmailHtml(raw, {});
    expect(out).toContain('href="https://bybata.com/open-app"');
  });
});
