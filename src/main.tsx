import { Component, ErrorInfo, ReactNode, StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'

class AppErrorBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null }

  static getDerivedStateFromError(error: Error) {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Kanni Mol Chat runtime error', error, info)
  }

  render() {
    if (this.state.error) {
      return <main className="public-page centered-page"><div className="auth-panel setup-notice"><div className="setup-icon">!</div><p className="eyebrow">The app could not open</p><h1>Something went <em>wrong.</em></h1><p className="muted">Refresh the page and try again. If the problem continues, check the browser console for the runtime error.</p><button className="primary wide" onClick={() => window.location.reload()}>Refresh app</button></div></main>
    }
    return this.props.children
  }
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AppErrorBoundary>
      <App />
    </AppErrorBoundary>
  </StrictMode>,
)
