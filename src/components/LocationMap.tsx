import React, { useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import { Contact } from '../types';
import { Crosshair } from 'lucide-react';

// Fix Leaflet's default icon path issues
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// Custom icon for contacts
const contactIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-violet.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

// Custom icon for user
const userIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

// Custom icon for addresses
const houseIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-gold.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

interface LocationMapProps {
  contacts: Contact[];
  onSelectContact: (contact: Contact) => void;
}

const MapController = ({ userPos }: { userPos: [number, number] | null }) => {
  const map = useMap();
  
  useEffect(() => {
    if (userPos) {
      // Add a global function to zoom to user
      (window as any).zoomToUser = () => {
        map.flyTo(userPos, 15, { duration: 1.5 });
      };
    }
    return () => {
      delete (window as any).zoomToUser;
    };
  }, [map, userPos]);

  return null;
};

const LocationMap: React.FC<LocationMapProps> = ({ contacts, onSelectContact }) => {
  const [userPos, setUserPos] = React.useState<[number, number] | null>(null);

  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => setUserPos([pos.coords.latitude, pos.coords.longitude]),
        (err) => console.error('Error getting user position:', err)
      );
    }
  }, []);

  const defaultCenter: [number, number] = [20, 0];
  const defaultZoom = 2;

  return (
    <div className="relative w-full h-full">
      <MapContainer 
        center={defaultCenter} 
        zoom={defaultZoom} 
        className="w-full h-full z-0"
        zoomControl={false}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          className="map-tiles"
        />
        
        {contacts.map(contact => {
          const markers = [];
          
          if (contact.lat && contact.lng) {
            markers.push(
              <Marker 
                key={`${contact.id}-met`} 
                position={[contact.lat, contact.lng]}
                icon={contactIcon}
                eventHandlers={{
                  click: () => onSelectContact(contact),
                }}
              >
                <Popup>
                  <div className="font-semibold">{contact.name}</div>
                  <div className="text-sm text-gray-600">Met at: {contact.locationMet}</div>
                </Popup>
              </Marker>
            );
          }

          if (contact.addressLat && contact.addressLng) {
            markers.push(
              <Marker 
                key={`${contact.id}-address`} 
                position={[contact.addressLat, contact.addressLng]}
                icon={houseIcon}
                eventHandlers={{
                  click: () => onSelectContact(contact),
                }}
              >
                <Popup>
                  <div className="font-semibold">{contact.name}'s Address</div>
                  <div className="text-sm text-gray-600">{contact.address}</div>
                </Popup>
              </Marker>
            );
          }

          return markers;
        })}

        {userPos && (
          <Marker position={userPos} icon={userIcon}>
            <Popup>
              <div className="font-semibold">You are here</div>
            </Popup>
          </Marker>
        )}

        <MapController userPos={userPos} />
      </MapContainer>

      {userPos && (
        <button
          onClick={() => (window as any).zoomToUser?.()}
          className="absolute top-24 right-6 bg-indigo-600 hover:bg-indigo-700 text-white p-3 rounded-full shadow-lg shadow-indigo-500/20 transition-all z-10 flex items-center justify-center"
          title="Zoom to my location"
        >
          <Crosshair size={24} />
        </button>
      )}
    </div>
  );
};

export default LocationMap;
