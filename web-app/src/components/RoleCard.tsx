import React from "react";
import type { Membership, Position } from "../types";

type Props = {
  membership: Membership;
  positions: Position[];
  className?: string;
  size?: "sm" | "md";
};

function resolveRoleLabel(m: Membership, positions: Position[]) {
  const pos = positions.find((p) => p.key === m.position_key);
  const role = (pos?.display && (pos.display.en || Object.values(pos.display)[0])) || pos?.key || m.position_key;
  const orgBits = (m.org_path || "/")
    .split("/")
    .filter(Boolean)
    .reverse()
    .map((bit) => bit.toUpperCase());
  return [role, ...orgBits].join(" • ");
}

function colorClassesFor(path?: string) {
  const p = path || "";
  if (p.startsWith("/club")) return "bg-orange-100/90 text-orange-700 ring-1 ring-orange-200";
  if (p.startsWith("/fac")) return "bg-green-100/90 text-green-700 ring-1 ring-green-200";
  return "bg-blue-100/90 text-blue-700 ring-1 ring-blue-200"; // default
}

const RoleCard: React.FC<Props> = ({ membership, positions, className, size = "sm" }) => {
  const label = resolveRoleLabel(membership, positions);
  const base = `${colorClassesFor(membership.org_path)} inline-block rounded-full shadow-sm ${size === "sm" ? "text-[11px] px-2.5 py-0.5" : "text-sm px-3 py-1"} transition hover:brightness-105`;
  return <span className={`${base} ${className || ""}`.trim()}>{label}</span>;
};

export default RoleCard;
