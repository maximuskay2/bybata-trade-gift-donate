"use client";

import * as React from "react";
import { clsx } from "clsx";

interface TabsContextType {
  value: string;
  onValueChange: (value: string) => void;
}

const TabsContext = React.createContext<TabsContextType | undefined>(undefined);

const useTabsContext = () => {
  const context = React.useContext(TabsContext);
  if (!context) {
    throw new Error("Tabs components must be used within a Tabs provider");
  }
  return context;
};

interface TabsProps {
  defaultValue?: string;
  value?: string;
  onValueChange?: (value: string) => void;
  children: React.ReactNode;
  className?: string;
}

const Tabs: React.FC<TabsProps> = ({
  defaultValue,
  value: controlledValue,
  onValueChange,
  children,
  className,
}) => {
  const [internalValue, setInternalValue] = React.useState(defaultValue || "");
  
  const value = controlledValue !== undefined ? controlledValue : internalValue;
  const setValue = onValueChange || setInternalValue;

  const contextValue: TabsContextType = {
    value,
    onValueChange: setValue,
  };

  return (
    <TabsContext.Provider value={contextValue}>
      <div className={clsx("w-full", className)}>
        {children}
      </div>
    </TabsContext.Provider>
  );
};

interface TabsListProps {
  children: React.ReactNode;
  className?: string;
}

const TabsList: React.FC<TabsListProps> = ({ children, className }) => {
  return (
    <div
      className={clsx(
        "inline-flex h-10 items-center justify-center rounded-md bg-gray-100 p-1 text-gray-600",
        className
      )}
    >
      {children}
    </div>
  );
};

interface TabsTriggerProps {
  value: string;
  children: React.ReactNode;
  className?: string;
}

const TabsTrigger: React.FC<TabsTriggerProps> = ({ value, children, className }) => {
  const { value: selectedValue, onValueChange } = useTabsContext();
  const isSelected = selectedValue === value;

  return (
    <button
      className={clsx(
        "inline-flex items-center justify-center whitespace-nowrap rounded-sm px-3 py-1.5 text-sm font-medium transition-all focus:outline-none disabled:pointer-events-none disabled:opacity-50",
        isSelected 
          ? "bg-white text-gray-900 shadow-sm"
          : "hover:bg-gray-200 hover:text-gray-900",
        className
      )}
      onClick={() => onValueChange(value)}
    >
      {children}
    </button>
  );
};

interface TabsContentProps {
  value: string;
  children: React.ReactNode;
  className?: string;
}

const TabsContent: React.FC<TabsContentProps> = ({ value, children, className }) => {
  const { value: selectedValue } = useTabsContext();
  
  if (selectedValue !== value) {
    return null;
  }

  return (
    <div
      className={clsx(
        "mt-2 focus:outline-none",
        className
      )}
    >
      {children}
    </div>
  );
};

export { Tabs, TabsList, TabsTrigger, TabsContent };