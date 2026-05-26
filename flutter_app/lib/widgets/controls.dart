import 'package:flutter/material.dart';
import '../models/contact.dart';

class Controls extends StatelessWidget {
  final PivotType pivot;
  final ValueChanged<PivotType> onPivotChanged;
  final VoidCallback onAddContact;

  const Controls({
    super.key,
    required this.pivot,
    required this.onPivotChanged,
    required this.onAddContact,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _ButtonDef(PivotType.mutual, Icons.people, 'Mutuals'),
      _ButtonDef(PivotType.location, Icons.map_outlined, 'Location'),
      _ButtonDef(PivotType.time, Icons.schedule, 'Timeline'),
    ];

    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: const Color(0xFF333333)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...buttons.map((btn) => _buildButton(btn)),
              Container(
                width: 1,
                height: 24,
                color: const Color(0xFF333333),
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              _buildAddButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(_ButtonDef btn) {
    final isActive = pivot == btn.pivot;
    return GestureDetector(
      onTap: () => onPivotChanged(btn.pivot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4f46e5) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366f1).withValues(alpha: 0.2),
                    blurRadius: 12,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              btn.icon,
              size: 18,
              color: isActive ? Colors.white : const Color(0xFF9ca3af),
            ),
            const SizedBox(width: 8),
            Text(
              btn.label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF9ca3af),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: onAddContact,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, size: 20, color: Colors.black),
      ),
    );
  }
}

class _ButtonDef {
  final PivotType pivot;
  final IconData icon;
  final String label;

  _ButtonDef(this.pivot, this.icon, this.label);
}
