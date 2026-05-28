import type { APIRoute, GetStaticPaths } from 'astro';
import { getCollection } from 'astro:content';

// Serves the raw Markdown for each docs page at `/<slug>.md`, e.g.
// `/guides/theming.md`. This is the target of the "View as Markdown" link and
// the source the "Copy page" button fetches - the LLM-friendly view of a page.
export const getStaticPaths: GetStaticPaths = async () => {
  const docs = await getCollection('docs');
  return docs.map((entry) => ({
    params: { slug: entry.id },
    props: { entry },
  }));
};

export const GET: APIRoute = ({ props }) => {
  const entry = (props as { entry: { data: { title: string; description?: string }; body?: string } }).entry;
  const { title, description } = entry.data;

  const parts = [`# ${title}`];
  if (description) parts.push('', `> ${description}`);
  parts.push('', (entry.body ?? '').trim(), '');

  return new Response(parts.join('\n'), {
    headers: { 'Content-Type': 'text/markdown; charset=utf-8' },
  });
};
