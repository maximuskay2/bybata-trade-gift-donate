import * as React from "react"

import { clsx } from "clsx"

export interface TextareaProps
  extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {}

const Textarea = React.forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ className, ...props }, ref) => {
    return (
      <textarea
        className={clsx(
          "flex min-h-[80px] w-full rounded-lg border border-gray-300 bg-white/50 backdrop-blur-sm px-4 py-2 text-sm placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:border-transparent transition-all disabled:cursor-not-allowed disabled:opacity-50 hover:border-gray-400",
          className
        )}
        ref={ref}
        {...props}
      />
    )
  }
)
Textarea.displayName = "Textarea"

export { Textarea }