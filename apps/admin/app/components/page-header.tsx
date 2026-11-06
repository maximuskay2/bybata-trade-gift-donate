import Link from "next/link";
import type { ReactNode } from "react";

export type Crumb = { label: string; href?: string };

export default function PageHeader({
  title,
  breadcrumb = [],
  actions,
  description,
}: {
  title: string;
  breadcrumb?: Crumb[];
  actions?: ReactNode;
  description?: string;
}) {
  return (
    <div className="mb-8">
      {breadcrumb.length > 0 && (
        <nav className="text-sm text-gray-500 mb-4 flex items-center gap-2">
          {breadcrumb.map((c, idx) => (
            <span key={idx} className="flex items-center gap-2">
              {c.href ? (
                <Link href={c.href} className="text-gray-600 hover:text-gray-900 hover:underline transition-colors">
                  {c.label}
                </Link>
              ) : (
                <span className="text-gray-900 font-medium">{c.label}</span>
              )}
              {idx < breadcrumb.length - 1 && <span className="text-gray-300">/</span>}
            </span>
          ))}
        </nav>
      )}
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">{title}</h1>
          {description && <p className="text-gray-600 text-base">{description}</p>}
        </div>
        {actions && <div className="flex items-center gap-2 flex-shrink-0">{actions}</div>}
      </div>
    </div>
  );
}