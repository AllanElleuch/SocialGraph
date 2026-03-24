import React from 'react';
import { Contact } from '../types';
import { X, MapPin, Calendar, Users, Tag } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';

interface ContactCardProps {
  contact: Contact | null;
  onClose: () => void;
}

const ContactCard: React.FC<ContactCardProps> = ({ contact, onClose }) => {
  if (!contact) return null;

  return (
    <AnimatePresence>
      <motion.div
        initial={{ x: 300, opacity: 0 }}
        animate={{ x: 0, opacity: 1 }}
        exit={{ x: 300, opacity: 0 }}
        className="fixed top-4 right-4 bottom-4 w-80 bg-[#1a1a1a] border border-[#333] rounded-2xl shadow-2xl p-6 overflow-y-auto z-50"
      >
        <div className="flex justify-between items-start mb-6">
          <h2 className="text-2xl font-bold text-white leading-tight">{contact.name}</h2>
          <button 
            onClick={onClose}
            className="p-1 hover:bg-[#333] rounded-full transition-colors text-gray-400"
          >
            <X size={20} />
          </button>
        </div>

        <div className="space-y-6">
          <div className="flex items-center gap-3 text-gray-400">
            <MapPin size={18} className="text-indigo-400" />
            <div className="flex flex-col">
              <span className="text-sm">{contact.locationMet}</span>
              {contact.lat && contact.lng && (
                <span className="text-[10px] text-gray-600">
                  {contact.lat.toFixed(4)}, {contact.lng.toFixed(4)}
                </span>
              )}
            </div>
          </div>

          <div className="flex items-center gap-3 text-gray-400">
            <Calendar size={18} className="text-indigo-400" />
            <span className="text-sm">Met on {new Date(contact.dateMet).toLocaleDateString()}</span>
          </div>

          <div className="space-y-2">
            <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-gray-500">
              <Tag size={14} />
              <span>Tags</span>
            </div>
            <div className="flex flex-wrap gap-2">
              {contact.tags.map(tag => (
                <span key={tag} className="px-2 py-1 bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 rounded-md text-xs">
                  {tag}
                </span>
              ))}
            </div>
          </div>

          <div className="space-y-2">
            <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-gray-500">
              <Users size={14} />
              <span>Connections</span>
            </div>
            <div className="text-sm text-gray-400">
              {contact.connections.length} mutual connections identified.
            </div>
          </div>

          {contact.lastInteraction && (
            <div className="pt-4 border-t border-[#333]">
              <div className="text-[10px] uppercase tracking-widest text-gray-600 mb-1">Last Interaction</div>
              <div className="text-xs text-gray-400">{new Date(contact.lastInteraction).toLocaleString()}</div>
            </div>
          )}
        </div>
      </motion.div>
    </AnimatePresence>
  );
};

export default ContactCard;
