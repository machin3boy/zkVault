"use client";
import React, { useEffect } from "react";
import { EvervaultCard } from "./components/ui/evervault-card";
import { LampDemo } from "./components/ui/lamp";
import { GoogleGeminiEffectDemo } from "./components/gemini";
import { useMotionValue } from "framer-motion";

function App() {
  // Create motion values individually
  const pathLength1 = useMotionValue(0);
  const pathLength2 = useMotionValue(0);
  const pathLength3 = useMotionValue(0);
  const pathLength4 = useMotionValue(0);
  const pathLength5 = useMotionValue(0);

  const pathLengths = [
    pathLength1,
    pathLength2,
    pathLength3,
    pathLength4,
    pathLength5,
  ];

  useEffect(() => {
    const handleScroll = () => {
      const scrollTop = window.scrollY || document.documentElement.scrollTop;
      pathLengths.forEach((motionValue) => {
        const incrementFactor = 0.1; // Adjust the increment factor as needed
        motionValue.set(scrollTop * incrementFactor);
      });
    };

    window.addEventListener("scroll", handleScroll);

    return () => {
      window.removeEventListener("scroll", handleScroll);
    };
  }, [pathLengths]); // Include pathLengths in the dependency array

  return (
      <div className="flex flex-col items-center justify-center min-h-screen bg-black bg-dot-white/[0.3] z-10">
        <LampDemo />
        <GoogleGeminiEffectDemo />
        <div className="mt-36 text-center font-semibold tracking-tight text-white text-4xl">
          Store Assets in <span className="text-sky-500">zkVault</span> With Bank-Level Security Using Custom MFA.
        </div>
        <div className="text-center font-semibold tracking-tight text-white text-4xl">
          Mint Mirrored Assets for Staking, DeFi, and Trading.
        </div>
        <div className="flex justify-center my-36">
          <EvervaultCard text="ETH" className="w-64 h-64 mx-10" />
          <EvervaultCard text="BTT" className="w-64 h-64 mx-10" />
          <EvervaultCard text="TRX" className="w-64 h-64 mx-10" />
        </div>
        <div className="text-center font-semibold tracking-tight text-white text-4xl">
          Leverage <span className="text-sky-500">Next-Generation Custom Security Logic</span> in Your Smart 
        </div>
        <div className="text-center font-semibold tracking-tight text-white text-4xl mb-36">
          Contracts Seamlessly.
        </div>
      </div>
  );
}

export default App;
