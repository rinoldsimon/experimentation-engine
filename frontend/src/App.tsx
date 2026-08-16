import { BrowserRouter, Link, NavLink, Route, Routes } from "react-router-dom"
import DashboardPage from "./pages/DashboardPage"
import PricingDemoPage from "./pages/PricingDemoPage"
import CheckoutDemoPage from "./pages/CheckoutDemoPage"
import GenericDemoPage from "./pages/GenericDemoPage"

function navLinkClassName({ isActive }: { isActive: boolean }) {
  return isActive ? "font-semibold text-indigo-600" : "text-slate-600 hover:text-slate-900"
}

function App() {
  return (
    <BrowserRouter>
      <div className="min-h-screen bg-slate-50">
        <header className="border-b border-slate-200 bg-white">
          <nav className="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
            <Link to="/" className="text-lg font-semibold text-slate-900">
              Experimentation Engine
            </Link>
            <div className="flex gap-6 text-sm">
              <NavLink to="/" className={navLinkClassName} end>
                Dashboard
              </NavLink>
              <NavLink to="/demo/pricing" className={navLinkClassName}>
                Demo: Pricing
              </NavLink>
              <NavLink to="/demo/checkout" className={navLinkClassName}>
                Demo: Checkout
              </NavLink>
            </div>
          </nav>
        </header>

        <main className="mx-auto max-w-5xl px-6 py-8">
          <Routes>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/demo/pricing" element={<PricingDemoPage />} />
            <Route path="/demo/checkout" element={<CheckoutDemoPage />} />
            <Route path="/demo/:experimentName" element={<GenericDemoPage />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  )
}

export default App
