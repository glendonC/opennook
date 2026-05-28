import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

const SITE = 'https://opennook.dev';

// Mirrors the site nav so the index reads in the same order a human browses it.
// Pages not listed here still appear, under "Other", so nothing is silently dropped.
const SECTIONS: { title: string; ids: string[] }[] = [
  { title: 'Getting started', ids: ['start/introduction', 'start/install', 'start/first-nook'] },
  { title: 'Customization', ids: ['guides/theming', 'guides/settings-chrome', 'guides/displays'] },
  { title: 'Components', ids: ['guides/file-shelf', 'guides/activity-queue', 'guides/volume-glyph'] },
  { title: 'Hosting', ids: ['guides/multiple-modules'] },
  { title: 'Reference', ids: ['reference/api', 'reference/troubleshooting'] },
];

export const GET: APIRoute = async () => {
  const docs = await getCollection('docs');
  const byId = new Map(docs.map((e) => [e.id, e]));
  const used = new Set<string>();

  const line = (id: string): string | null => {
    const e = byId.get(id);
    if (!e) return null;
    used.add(id);
    const desc = e.data.description ? `: ${e.data.description}` : '';
    return `- [${e.data.title}](${SITE}/${id}.md)${desc}`;
  };

  const lines: string[] = [
    '# OpenNook',
    '',
    '> An open-source Swift framework for building macOS notch apps: a hover-expanding notch window, app chrome, theming, and optional file-shelf / activity / volume components.',
    '',
    'Every page below is also available as raw Markdown by appending `.md` to its URL. The full text of all pages is at /llms-full.txt.',
  ];

  for (const section of SECTIONS) {
    const items = section.ids.map(line).filter((l): l is string => l !== null);
    if (items.length === 0) continue;
    lines.push('', `## ${section.title}`, '', ...items);
  }

  const leftover = docs.filter((e) => !used.has(e.id));
  if (leftover.length) {
    lines.push('', '## Other', '');
    for (const e of leftover) {
      const desc = e.data.description ? `: ${e.data.description}` : '';
      lines.push(`- [${e.data.title}](${SITE}/${e.id}.md)${desc}`);
    }
  }

  lines.push('');
  return new Response(lines.join('\n'), {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
};
