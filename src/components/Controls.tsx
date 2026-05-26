import React from 'react';
import { PivotType } from '../types';
import { Users, Map, Clock, Plus } from 'lucide-react';
import { cn } from '../lib/utils';

interface ControlsProps {
  pivot: PivotType;
  setPivot: (pivot: PivotType) => void;
  onAddContact: () => void;
}

const Controls: React.FC<ControlsProps> = ({ pivot, setPivot, onAddContact }) => {
  const buttons = [
    { id: 'mutual', icon: Users, label: 'Mutuals' },
    { id: 'location', icon: Map, label: 'Location' },
    { id: 'time', icon: Clock, label: 'Timeline' },
  ];

  return (
    <div className="fixed bottom-4 md:bottom-8 left-1/2 -translate-x-1/2 flex items-center gap-1 md:gap-2 p-1.5 md:p-2 bg-[#1a1a1a]/80 backdrop-blur-md border border-[#333] rounded-full shadow-2xl z-40 w-[95%] max-w-fit overflow-x-auto">
      {buttons.map((btn) => (
        <button
          key={btn.id}
          onClick={() => setPivot(btn.id as PivotType)}
          className={cn(
            "flex items-center gap-1.5 md:gap-2 px-3 md:px-4 py-2 rounded-full transition-all duration-300 shrink-0",
            pivot === btn.id 
              ? "bg-indigo-600 text-white shadow-lg shadow-indigo-500/20" 
              : "text-gray-400 hover:text-white hover:bg-[#333]"
          )}
        >
          <btn.icon size={16} className="md:w-[18px] md:h-[18px]" />
          <span className="text-xs md:text-sm font-medium">{btn.label}</span>
        </button>
      ))}
      <div className="w-px h-6 bg-[#333] mx-1 shrink-0" />
      <button
        onClick={onAddContact}
        className="p-1.5 md:p-2 bg-white text-black rounded-full hover:bg-gray-200 transition-colors shrink-0"
        title="Add Contact"
      >
        <Plus size={18} className="md:w-[20px] md:h-[20px]" />
      </button>
    </div>
  );
};

export default Controls;
